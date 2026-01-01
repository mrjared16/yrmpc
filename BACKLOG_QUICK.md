# Backlog CLI Quick Reference

## Create Task
```bash
backlog task create "Title" -d "Description" --ac "AC 1" --ac "AC 2"
```

## Edit Task
```bash
backlog task edit <id> -s "In Progress" -a @agent      # Status + Assign
backlog task edit <id> --ac "New criterion"             # Add AC
backlog task edit <id> --check-ac 1                     # Check AC #1
backlog task edit <id> --plan "1. Step\n2. Step"        # Add plan
backlog task edit <id> --notes "What I did"             # Replace notes
backlog task edit <id> --append-notes "Progress"        # Append notes
```

## View/List
```bash
backlog task list --plain                               # All tasks
backlog task <id> --plain                               # View task
backlog search "keyword" --plain                        # Search
```

## Rules
- ✅ Use `--plain` for all list/search/view commands
- ✅ Multi-word values need quotes: `-s "In Progress"`
- ❌ NO `--priority` flag
- ❌ NO `backlog task add` command (use `create` or `edit`)
