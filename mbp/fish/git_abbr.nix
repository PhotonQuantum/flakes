let
  _git_log_fuller_format = "%C(bold yellow)commit %H%C(auto)%d%n%C(bold)Author: %C(blue)%an <%ae> %C(reset)%C(cyan)%ai (%ar)%n%C(bold)Commit: %C(blue)%cn <%ce> %C(reset)%C(cyan)%ci (%cr)%C(reset)%n%+B";
  _git_log_oneline_format = "%C(bold yellow)%h%C(reset) %s%C(auto)%d%C(reset)";
  _git_log_oneline_medium_format = "%C(bold yellow)%h%C(reset) %<(50,trunc)%s %C(bold blue)%an %C(reset)%C(cyan)%as (%ar)%C(auto)%d%C(reset)";
in
{
  # Git
  G = "git";

  # Branch (b)
  Gb = "git branch";
  Gbc = "git checkout -b";
  Gbd = "git checkout --detach";
  Gbl = "git branch -vv";
  GbL = "git branch --all -vv";
  Gbm = "git branch --move";
  GbM = "git branch --move --force";
  GbR = "git branch --force";
  Gbs = "git show-branch";
  GbS = "git show-branch --all";
  Gbu = "git branch --unset-upstream";
  GbG = "git-branch-remote-tracking gone | xargs -r git branch --delete --force";
  Gbx = "git-branch-delete-interactive";
  GbX = "git-branch-delete-interactive --force";

  # Commit (c)
  Gc = "git commit --verbose";
  Gca = "git commit --verbose --all";
  GcA = "git commit --verbose --patch";
  Gcm = "git commit --message";
  Gco = "git checkout";
  GcO = "git checkout --patch";
  Gcf = "git commit --amend --reuse-message HEAD";
  GcF = "git commit --verbose --amend";
  Gcp = "git cherry-pick";
  GcP = "git cherry-pick --no-commit";
  Gcr = "git revert";
  GcR = "git reset \"HEAD^\"";
  Gcs = "git show --pretty=format:\"${_git_log_fuller_format}\"";
  GcS = "git commit --verbose -S";
  Gcu = "git commit --fixup";
  GcU = "git commit --squash";
  Gcv = "git verify-commit";

  # Conflict (C)
  GCl = "git --no-pager diff --diff-filter=U --name-only";
  GCa = "git add \$(GCl)";
  GCe = "git mergetool \$(GCl)";
  GCo = "git checkout --ours --";
  GCO = "GCo \$(GCl)";
  GCt = "git checkout --theirs --";
  GCT = "GCt \$(GCl)";

  # Data (d)
  Gd = "git ls-files";
  Gdc = "git ls-files --cached";
  Gdx = "git ls-files --deleted";
  Gdm = "git ls-files --modified";
  Gdu = "git ls-files --other --exclude-standard";
  Gdk = "git ls-files --killed";
  Gdi = "git status --porcelain --short --ignored | sed -n \"s/^!! //p\"";

  # Fetch (f)
  Gf = "git fetch";
  Gfa = "git fetch --all";
  Gfp = "git fetch --all --prune";
  Gfc = "git clone";
  Gfm = "git pull --no-rebase";
  Gfr = "git pull --rebase";
  Gfu = "git pull --ff-only --all --prune";

  # Grep (g)
  Gg = "git grep";
  Ggi = "git grep --ignore-case";
  Ggl = "git grep --files-with-matches";
  GgL = "git grep --files-without-match";
  Ggv = "git grep --invert-match";
  Ggw = "git grep --word-regexp";

  # Help (h)
  Gh = "git help";

  # Index (i)
  Gia = "git add";
  GiA = "git add --patch";
  Giu = "git add --update";
  Gid = "git diff --no-ext-diff --cached";
  GiD = "git diff --no-ext-diff --cached --word-diff";
  Gir = "git reset";
  GiR = "git reset --patch";
  Gix = "git rm --cached -r";
  GiX = "git rm --cached -rf";

  # Log (l)
  Gl = "git log --topo-order --pretty=format:\"${_git_log_fuller_format}\"";
  Gls = "git log --topo-order --stat --pretty=format:\"${_git_log_fuller_format}\"";
  Gld = "git log --topo-order --stat --patch --pretty=format:\"${_git_log_fuller_format}\"";
  Glf = "git log --topo-order --stat --patch --follow --pretty=format:\"${_git_log_fuller_format}\"";
  Glo = "git log --topo-order --pretty=format:\"${_git_log_oneline_format}\"";
  GlO = "git log --topo-order --pretty=format:\"${_git_log_oneline_medium_format}\"";
  Glg = "git log --graph --pretty=format:\"${_git_log_oneline_format}\"";
  GlG = "git log --graph --pretty=format:\"${_git_log_oneline_medium_format}\"";
  Glv = "git log --topo-order --show-signature --pretty=format:\"${_git_log_fuller_format}\"";
  Glc = "git shortlog --summary --numbered";
  Glr = "git reflog";

  # Merge (m)
  Gm = "git merge";
  Gma = "git merge --abort";
  Gmc = "git merge --continue";
  GmC = "git merge --no-commit";
  GmF = "git merge --no-ff";
  GmS = "git merge -S";
  Gmv = "git merge --verify-signatures";
  Gmt = "git mergetool";

  # Push (p)
  Gp = "git push";
  Gpf = "git push --force-with-lease";
  GpF = "git push --force";
  Gpa = "git push --all";
  GpA = "git push --all && git push --tags --no-verify";
  Gpt = "git push --tags";
  Gpc = "git push --set-upstream origin \"$(git-branch-current 2>/dev/null)\"";
  Gpp = "git pull origin \"$(git-branch-current 2>/dev/null)\" && git push origin \"$(git-branch-current 2>/dev/null)\"";

  # Rebase (r)
  Gr = "git rebase";
  Gra = "git rebase --abort";
  Grc = "git rebase --continue";
  Gri = "git rebase --interactive --autosquash";
  Grs = "git rebase --skip";
  GrS = "git rebase --exec \"git commit --amend --no-edit --no-verify -S\"";

  # Remote (R)
  GR = "git remote";
  GRl = "git remote --verbose";
  GRa = "git remote add";
  GRx = "git remote rm";
  GRm = "git remote rename";
  GRu = "git remote update";
  GRp = "git remote prune";
  GRs = "git remote show";
  GRS = "git remote set-url";

  # Stash (s)
  Gs = "git stash";
  Gsa = "git stash apply";
  Gsx = "git stash drop";
  GsX = "git-stash-clear-interactive";
  Gsl = "git stash list";
  Gsd = "git stash show --patch --stat";
  Gsp = "git stash pop";
  Gsr = "git-stash-recover";
  Gss = "git stash save --include-untracked";
  GsS = "git stash save --patch --no-keep-index";
  Gsw = "git stash save --include-untracked --keep-index";
  Gsi = "git stash push --staged";
  Gsu = "git stash show --patch | git apply --reverse";

  # Submodule (S)
  GS = "git submodule";
  GSa = "git submodule add";
  GSf = "git submodule foreach";
  GSi = "git submodule init";
  GSI = "git submodule update --init --recursive";
  GSl = "git submodule status";
  GSm = "git-submodule-move";
  GSs = "git submodule sync";
  GSu = "git submodule update --remote";
  GSx = "git-submodule-remove";

  # Tag (t)
  Gt = "git tag";
  Gtl = "git tag --list --sort=-committerdate";
  Gts = "git tag --sign";
  Gtv = "git verify-tag";
  Gtx = "git tag --delete";

  # Main working tree (w)
  Gws = "git status --short";
  GwS = "git status";
  Gwd = "git diff --no-ext-diff";
  GwD = "git diff --no-ext-diff --word-diff";
  Gwr = "git reset --soft";
  GwR = "git reset --hard";
  Gwc = "git clean --dry-run";
  GwC = "git clean -d --force";
  Gwm = "git mv";
  GwM = "git mv -f";
  Gwx = "git rm -r";
  GwX = "git rm -rf";

  # Working trees (W)
  GW = "git worktree";
  GWa = "git worktree add";
  GWl = "git worktree list";
  GWm = "git worktree move";
  GWp = "git worktree prune";
  GWx = "git worktree remove";
  GWX = "git worktree remove --force";

  # Switch (y)
  Gy = "git switch";
  Gyd = "git switch --detach";

  # Misc
  "G.." = "cd \"$(git-root || print .)\"";
}
