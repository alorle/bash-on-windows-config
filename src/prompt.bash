# If we are on a colored terminal
if tput setaf 1 &> /dev/null; then
  # Reset the shell from our `if` check
  tput sgr0 &> /dev/null

  # Save common color actions
  prompt_bold="$(tput bold)"
  prompt_reset="$(tput sgr0)"

  # If the terminal supports at least 256 colors, write out our 256 color based set
  if [[ "$(tput colors)" -ge 256 ]] &> /dev/null; then
    if [[ "$UID" == 0 ]]; then
      prompt_user_color="$prompt_bold$(tput setaf 9)"       # BOLD RED
    else
      prompt_user_color="$prompt_bold$(tput setaf 27)"      # BOLD BLUE
    fi
    prompt_preposition_color="$prompt_bold$(tput setaf 7)"  # BOLD WHITE
    prompt_device_color="$prompt_bold$(tput setaf 39)"      # BOLD CYAN
    prompt_dir_color="$prompt_bold$(tput setaf 76)"         # BOLD GREEN
    prompt_git_status_color="$prompt_bold$(tput setaf 154)" # BOLD YELLOW
    prompt_git_progress_color="$prompt_bold$(tput setaf 9)" # BOLD RED

  # Otherwise, use colors from our set of 8
  else
    if [[ "$UID" == 0 ]]; then
      prompt_user_color="$prompt_bold$(tput setaf 1)"       # BOLD RED
    else
      prompt_user_color="$prompt_bold$(tput setaf 4)"       # BOLD BLUE
    fi
    prompt_preposition_color="$prompt_bold$(tput setaf 7)"  # BOLD WHITE
    prompt_device_color="$prompt_bold$(tput setaf 6)"       # BOLD CYAN
    prompt_dir_color="$prompt_bold$(tput setaf 2)"          # BOLD GREEN
    prompt_git_status_color="$prompt_bold$(tput setaf 3)"   # BOLD YELLOW
    prompt_git_progress_color="$prompt_bold$(tput setaf 1)" # BOLD RED
  fi

  prompt_symbol_color="$prompt_bold" # BOLD

# Otherwise, use ANSI escape sequences for coloring
else
  prompt_reset="\033[m"
  if [[ "$UID" == 0 ]]; then
    prompt_user_color="\033[1;31m"          # RED
  else
    prompt_user_color="\033[1;34m"          # BLUE
  fi
  prompt_preposition_color="\033[1;37m"     # WHITE
  prompt_device_color="\033[1;36m"          # CYAN
  prompt_dir_color="\033[1;32m"             # GREEN
  prompt_git_status_color="\033[1;33m"      # YELLOW
  prompt_git_progress_color="\033[1;31m"    # RED
  prompt_symbol_color=""                    # NORMAL
fi

# Define the default prompt terminator character '$'
if [[ "$UID" == 0 ]]; then
  prompt_symbol="#"
else
  prompt_symbol="\$"
fi

# Apply any color overrides that have been set in the environment
if [[ -n "$PROMPT_USER_COLOR" ]]; then prompt_user_color="$PROMPT_USER_COLOR"; fi
if [[ -n "$PROMPT_PREPOSITION_COLOR" ]]; then prompt_preposition_color="$PROMPT_PREPOSITION_COLOR"; fi
if [[ -n "$PROMPT_DEVICE_COLOR" ]]; then prompt_device_color="$PROMPT_DEVICE_COLOR"; fi
if [[ -n "$PROMPT_DIR_COLOR" ]]; then prompt_dir_color="$PROMPT_DIR_COLOR"; fi
if [[ -n "$PROMPT_GIT_STATUS_COLOR" ]]; then prompt_git_status_color="$PROMPT_GIT_STATUS_COLOR"; fi
if [[ -n "$PROMPT_GIT_PROGRESS_COLOR" ]]; then prompt_git_progress_color="$PROMPT_GIT_PROGRESS_COLOR"; fi
if [[ -n "$PROMPT_SYMBOL" ]]; then prompt_symbol="$PROMPT_SYMBOL"; fi
if [[ -n "$PROMPT_SYMBOL_COLOR" ]]; then prompt_symbol_color="$PROMPT_SYMBOL_COLOR"; fi

# Set up symbols
prompt_synced_symbol=""
prompt_dirty_synced_symbol="*"
prompt_unpushed_symbol="△"
prompt_dirty_unpushed_symbol="▲"
prompt_unpulled_symbol="▽"
prompt_dirty_unpulled_symbol="▼"
prompt_unpushed_unpulled_symbol="⬡"
prompt_dirty_unpushed_unpulled_symbol="⬢"

# Apply symbol overrides that have been set in the environment
# DEV: Working unicode symbols can be determined via the following gist
#   **WARNING: The following gist has 64k lines and may freeze your browser**
#   https://gist.github.com/twolfson/9cc7968eb6ee8b9ad877
if [[ -n "$PROMPT_SYNCED_SYMBOL" ]]; then prompt_synced_symbol="$PROMPT_SYNCED_SYMBOL"; fi
if [[ -n "$PROMPT_DIRTY_SYNCED_SYMBOL" ]]; then prompt_dirty_synced_symbol="$PROMPT_DIRTY_SYNCED_SYMBOL"; fi
if [[ -n "$PROMPT_UNPUSHED_SYMBOL" ]]; then prompt_unpushed_symbol="$PROMPT_UNPUSHED_SYMBOL"; fi
if [[ -n "$PROMPT_DIRTY_UNPUSHED_SYMBOL" ]]; then prompt_dirty_unpushed_symbol="$PROMPT_DIRTY_UNPUSHED_SYMBOL"; fi
if [[ -n "$PROMPT_UNPULLED_SYMBOL" ]]; then prompt_unpulled_symbol="$PROMPT_UNPULLED_SYMBOL"; fi
if [[ -n "$PROMPT_DIRTY_UNPULLED_SYMBOL" ]]; then prompt_dirty_unpulled_symbol="$PROMPT_DIRTY_UNPULLED_SYMBOL"; fi
if [[ -n "$PROMPT_UNPUSHED_UNPULLED_SYMBOL" ]]; then prompt_unpushed_unpulled_symbol="$PROMPT_UNPUSHED_UNPULLED_SYMBOL"; fi
if [[ -n "$PROMPT_DIRTY_UNPUSHED_UNPULLED_SYMBOL" ]]; then prompt_dirty_unpushed_unpulled_symbol="$PROMPT_DIRTY_UNPUSHED_UNPULLED_SYMBOL"; fi

function prompt_get_git_branch() {
  # On branches, this will return the branch name
  # On non-branches, (no branch)
  ref="$(git symbolic-ref HEAD 2> /dev/null | sed -e 's/refs\/heads\///')"
  if [[ "$ref" != "" ]]; then
    echo "$ref"
  else
    echo "(no branch)"
  fi
}

function prompt_get_git_progress() {
  # Detect in-progress actions (e.g. merge, rebase)
  # https://github.com/git/git/blob/v1.9-rc2/wt-status.c#L1199-L1241
  git_dir="$(git rev-parse --git-dir)"

  # git merge
  if [[ -f "$git_dir/MERGE_HEAD" ]]; then
    echo " [merge]"
  elif [[ -d "$git_dir/rebase-apply" ]]; then
    # git am
    if [[ -f "$git_dir/rebase-apply/applying" ]]; then
      echo " [am]"
    # git rebase
    else
      echo " [rebase]"
    fi
  elif [[ -d "$git_dir/rebase-merge" ]]; then
    # git rebase --interactive/--merge
    echo " [rebase]"
  elif [[ -f "$git_dir/CHERRY_PICK_HEAD" ]]; then
    # git cherry-pick
    echo " [cherry-pick]"
  fi
  if [[ -f "$git_dir/BISECT_LOG" ]]; then
    # git bisect
    echo " [bisect]"
  fi
  if [[ -f "$git_dir/REVERT_HEAD" ]]; then
    # git revert --no-commit
    echo " [revert]"
  fi
}

prompt_is_branch1_behind_branch2 () {
  # $ git log origin/master..master -1
  # commit 4a633f715caf26f6e9495198f89bba20f3402a32
  # Author: Todd Wolfson <todd@twolfson.com>
  # Date:   Sun Jul 7 22:12:17 2013 -0700
  #
  #     Unsynced commit

  # Find the first log (if any) that is in branch1 but not branch2
  first_log="$(git log $1..$2 -1 2> /dev/null)"

  # Exit with 0 if there is a first log, 1 if there is not
  [[ -n "$first_log" ]]
}

prompt_branch_exists () {
  # List remote branches           | # Find our branch and exit with 0 or 1 if found/not found
  git branch --remote 2> /dev/null | grep --quiet "$1"
}

prompt_parse_git_ahead () {
  # Grab the local and remote branch
  branch="$(prompt_get_git_branch)"
  remote_branch="origin/$branch"

  # $ git log origin/master..master
  # commit 4a633f715caf26f6e9495198f89bba20f3402a32
  # Author: Todd Wolfson <todd@twolfson.com>
  # Date:   Sun Jul 7 22:12:17 2013 -0700
  #
  #     Unsynced commit

  # If the remote branch is behind the local branch
  # or it has not been merged into origin (remote branch doesn't exist)
  if (prompt_is_branch1_behind_branch2 "$remote_branch" "$branch" ||
      ! prompt_branch_exists "$remote_branch"); then
    # echo our character
    echo 1
  fi
}

prompt_parse_git_behind () {
  # Grab the branch
  branch="$(prompt_get_git_branch)"
  remote_branch="origin/$branch"

  # $ git log master..origin/master
  # commit 4a633f715caf26f6e9495198f89bba20f3402a32
  # Author: Todd Wolfson <todd@twolfson.com>
  # Date:   Sun Jul 7 22:12:17 2013 -0700
  #
  #     Unsynced commit

  # If the local branch is behind the remote branch
  if prompt_is_branch1_behind_branch2 "$branch" "$remote_branch"; then
    # echo our character
    echo 1
  fi
}

function prompt_parse_git_dirty() {
  # If the git status has *any* changes (e.g. dirty), echo our character
  if [[ -n "$(git status --porcelain 2> /dev/null)" ]]; then
    echo 1
  fi
}

function prompt_is_on_git() {
  git rev-parse 2> /dev/null
}

function prompt_get_git_status() {
  # Grab the git dirty and git behind
  dirty_branch="$(prompt_parse_git_dirty)"
  branch_ahead="$(prompt_parse_git_ahead)"
  branch_behind="$(prompt_parse_git_behind)"

  # Iterate through all the cases and if it matches, then echo
  if [[ "$dirty_branch" == 1 && "$branch_ahead" == 1 && "$branch_behind" == 1 ]]; then
    echo "$prompt_dirty_unpushed_unpulled_symbol"
  elif [[ "$branch_ahead" == 1 && "$branch_behind" == 1 ]]; then
    echo "$prompt_unpushed_unpulled_symbol"
  elif [[ "$dirty_branch" == 1 && "$branch_ahead" == 1 ]]; then
    echo "$prompt_dirty_unpushed_symbol"
  elif [[ "$branch_ahead" == 1 ]]; then
    echo "$prompt_unpushed_symbol"
  elif [[ "$dirty_branch" == 1 && "$branch_behind" == 1 ]]; then
    echo "$prompt_dirty_unpulled_symbol"
  elif [[ "$branch_behind" == 1 ]]; then
    echo "$prompt_unpulled_symbol"
  elif [[ "$dirty_branch" == 1 ]]; then
    echo "$prompt_dirty_synced_symbol"
  else # clean
    echo "$prompt_synced_symbol"
  fi
}

prompt_get_git_info () {
  # Grab the branch
  branch="$(prompt_get_git_branch)"

  # If there are any branches
  if [[ "$branch" != "" ]]; then
    # Echo the branch
    output="$branch"

    # Add on the git status
    output="$output$(prompt_get_git_status)"

    # Echo our output
    echo "$output"
  fi
}

# Define the prompt
PS1="\[$prompt_user_color\]\u\[$prompt_reset\] \
\[$prompt_preposition_color\]at\[$prompt_reset\] \
\[$prompt_device_color\]\h\[$prompt_reset\] \
\[$prompt_preposition_color\]in\[$prompt_reset\] \
\[$prompt_dir_color\]\W\[$prompt_reset\]\
\$( prompt_is_on_git && \
  echo -n \" \[$prompt_preposition_color\]on\[$prompt_reset\] \" && \
  echo -n \"\[$prompt_git_status_color\]\$(prompt_get_git_info)\" && \
  echo -n \"\[$prompt_git_progress_color\]\$(prompt_get_git_progress)\" && \
  echo -n \"\[$prompt_preposition_color\]\")\n\[$prompt_reset\]\
\[$prompt_symbol_color\]$prompt_symbol \[$prompt_reset\]"
