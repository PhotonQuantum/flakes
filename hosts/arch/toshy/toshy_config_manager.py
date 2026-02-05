#!/usr/bin/env python3
"""
Toshy Configuration Manager

This script allows you to extract custom configurations from toshy_config.py
into a separate file and apply them back, making it easier to manage and
persist custom settings across Toshy upgrades.
"""

import argparse
import re
import sys
from pathlib import Path
from datetime import datetime
from typing import Dict


class ToshyConfigManager:
    """Manages extraction and application of Toshy custom configurations."""

    SLICE_START_PATTERN = r"###\s+SLICE_MARK_START:\s+(\w+)\s+###.*"
    SLICE_END_PATTERN = r"###\s+SLICE_MARK_END:\s+(\w+)\s+###.*"

    def __init__(self, toshy_config_path: Path):
        """Initialize the manager with the path to toshy_config.py."""
        self.toshy_config_path = toshy_config_path

    def extract_slices(self) -> Dict[str, str]:
        """
        Extract all SLICE_MARK sections from toshy_config.py.

        Returns:
            Dict mapping section names to their content
        """
        if not self.toshy_config_path.exists():
            raise FileNotFoundError(f"Config file not found: {self.toshy_config_path}")

        with open(self.toshy_config_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        slices = {}
        current_section = None
        current_content = []

        for line in lines:
            # Check for SLICE_MARK_START
            start_match = re.match(self.SLICE_START_PATTERN, line)
            if start_match:
                current_section = start_match.group(1)
                current_content = []
                continue

            # Check for SLICE_MARK_END
            end_match = re.match(self.SLICE_END_PATTERN, line)
            if end_match:
                section_name = end_match.group(1)
                if current_section == section_name:
                    # Store the content (without trailing newline if empty)
                    content = "".join(current_content)
                    slices[current_section] = content
                    current_section = None
                    current_content = []
                else:
                    print(
                        f"Warning: Mismatched section markers: {current_section} vs {section_name}",
                        file=sys.stderr,
                    )
                continue

            # Collect content if we're inside a section
            if current_section is not None:
                current_content.append(line)

        return slices

    def generate_custom_config(self, slices: Dict[str, str], output_path: Path):
        """
        Generate a Python config file with extracted slices.

        Args:
            slices: Dict mapping section names to content
            output_path: Path where to write the custom config
        """
        with open(output_path, "w", encoding="utf-8") as f:
            f.write("#!/usr/bin/env python3\n")
            f.write('"""\n')
            f.write("Toshy Custom Configuration\n")
            f.write("\n")
            f.write(
                "This file stores your custom configurations extracted from toshy_config.py.\n"
            )
            f.write("Edit the content between the triple quotes for each section.\n")
            f.write("\n")
            f.write(f'Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}\n')
            f.write('"""\n\n')

            f.write("# Dictionary mapping section names to their custom content\n")
            f.write("slices = {\n")

            for section_name, content in sorted(slices.items()):
                f.write(f"    '{section_name}': '''\n")
                f.write(content)
                f.write("''',\n\n")

            f.write("}\n")

        print(f"Custom configuration extracted to: {output_path}")
        print(f"Found {len(slices)} sections: {', '.join(sorted(slices.keys()))}")

    def load_custom_config(self, custom_config_path: Path) -> Dict[str, str]:
        """
        Load slices from a custom config file.

        Args:
            custom_config_path: Path to the custom config file

        Returns:
            Dict mapping section names to content
        """
        if not custom_config_path.exists():
            raise FileNotFoundError(
                f"Custom config file not found: {custom_config_path}"
            )

        # Execute the Python file to load the slices dictionary
        namespace = {}
        with open(custom_config_path, "r", encoding="utf-8") as f:
            exec(f.read(), namespace)

        if "slices" not in namespace:
            raise ValueError("Custom config file must contain a 'slices' dictionary")

        slices = namespace["slices"]
        if not isinstance(slices, dict):
            raise ValueError("'slices' must be a dictionary")

        return slices

    def apply_slices(self, slices: Dict[str, str], backup: bool = True):
        """
        Apply custom slices to toshy_config.py.

        Args:
            slices: Dict mapping section names to content
            backup: Whether to create a backup before modifying
        """
        if not self.toshy_config_path.exists():
            raise FileNotFoundError(f"Config file not found: {self.toshy_config_path}")

        # Create backup if requested
        if backup:
            backup_path = self.create_backup()
            print(f"Backup created: {backup_path}")

        # Read the current config
        with open(self.toshy_config_path, "r", encoding="utf-8") as f:
            lines = f.readlines()

        # Process the file and replace slice contents
        new_lines = []
        current_section = None
        sections_found = set()

        for line in lines:
            # Check for SLICE_MARK_START
            start_match = re.match(self.SLICE_START_PATTERN, line)
            if start_match:
                current_section = start_match.group(1)
                sections_found.add(current_section)
                new_lines.append(line)  # Keep the start marker

                # Insert the custom content if available
                if current_section in slices:
                    new_lines.append(slices[current_section])
                continue

            # Check for SLICE_MARK_END
            end_match = re.match(self.SLICE_END_PATTERN, line)
            if end_match:
                section_name = end_match.group(1)
                if current_section == section_name:
                    new_lines.append(line)  # Keep the end marker
                    current_section = None
                else:
                    print(
                        f"Warning: Mismatched section markers: {current_section} vs {section_name}",
                        file=sys.stderr,
                    )
                    new_lines.append(line)
                continue

            # Skip lines that are inside a section (they'll be replaced by custom content)
            if current_section is not None:
                continue

            # Keep all other lines
            new_lines.append(line)

        # Validate that all custom sections exist in the config
        custom_sections = set(slices.keys())
        missing_sections = custom_sections - sections_found
        if missing_sections:
            print(
                "Warning: The following sections in custom config were not found in toshy_config.py:",
                file=sys.stderr,
            )
            for section in sorted(missing_sections):
                print(f"  - {section}", file=sys.stderr)

        # Write the modified config
        with open(self.toshy_config_path, "w", encoding="utf-8") as f:
            f.writelines(new_lines)

        print(
            f"Applied {len(sections_found & custom_sections)} sections to {self.toshy_config_path}"
        )
        if sections_found & custom_sections:
            print(
                f"Modified sections: {', '.join(sorted(sections_found & custom_sections))}"
            )

    def create_backup(self) -> Path:
        """
        Create a timestamped backup of toshy_config.py.

        Returns:
            Path to the backup file
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = (
            self.toshy_config_path.parent / f"toshy_config.py.backup_{timestamp}"
        )

        with open(self.toshy_config_path, "r", encoding="utf-8") as src:
            with open(backup_path, "w", encoding="utf-8") as dst:
                dst.write(src.read())

        return backup_path


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description="Manage Toshy custom configurations",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Extract current customizations to a file
  %(prog)s --extract --config-file my_toshy_custom.py

  # Apply customizations from a file
  %(prog)s --apply --config-file my_toshy_custom.py

  # Use a different toshy_config.py location
  %(prog)s --extract --toshy-config /path/to/toshy_config.py --config-file my_custom.py

  # Apply without creating a backup (not recommended)
  %(prog)s --apply --config-file my_custom.py --no-backup
        """,
    )

    # Mode selection
    mode_group = parser.add_mutually_exclusive_group(required=True)
    mode_group.add_argument(
        "--extract",
        action="store_true",
        help="Extract custom configurations from toshy_config.py",
    )
    mode_group.add_argument(
        "--apply",
        action="store_true",
        help="Apply custom configurations to toshy_config.py",
    )

    # File paths
    parser.add_argument(
        "--toshy-config",
        type=Path,
        default=Path.home() / ".config" / "toshy" / "toshy_config.py",
        help="Path to toshy_config.py (default: ~/.config/toshy/toshy_config.py)",
    )
    parser.add_argument(
        "--config-file",
        type=Path,
        required=True,
        help="Path to the separate custom configuration file",
    )

    # Options
    parser.add_argument(
        "--no-backup",
        action="store_true",
        help="Do not create a backup when applying (not recommended)",
    )

    args = parser.parse_args()

    try:
        manager = ToshyConfigManager(args.toshy_config)

        if args.extract:
            # Extract mode
            slices = manager.extract_slices()
            manager.generate_custom_config(slices, args.config_file)

        elif args.apply:
            # Apply mode
            slices = manager.load_custom_config(args.config_file)
            manager.apply_slices(slices, backup=not args.no_backup)

        return 0

    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        import traceback

        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
