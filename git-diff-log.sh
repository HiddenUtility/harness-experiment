echo "[git status --short]" > git-dff.log
git status --short >> git-dff.log
echo "[git diff --stat]" >> git-dff.log
git diff --stat >> git-dff.log
echo "[git diff]" >> git-dff.log
git diff >> git-dff.log