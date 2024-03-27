# Dredge - Dredging up secrets from the depths of a filesystem.
![image](https://github.com/grahamhelton/dredge/assets/19278569/3b58847c-a9b7-46ba-b682-971010b372bf)

Dredge is a linux command-line tool for finding and logging secrets on a filesystem for manual inspection.

# Why Dredge?
Casting a wide net when searching for secrets is a tedious task due to the large number of false positives that can be returned when doing generic queries for strings such as `key=`,`token=`, or simply `password`. Running a simple command such as `grep -Ri "password"` isn't a scaleable solution.

Dredge aims to make hunting for sensitive files on a linux system less painful by allowing a large quantity of strings to be queried at a time by utilizing a wordlist. Additionally, if a match *is* found, it is logged in a format that allows for quick manual analysis. Manual analysis is necessary when querying for strings such as `password=` due to the infinite number of things that could follow `password=` that is not actually a sensitive password.

Why not use `$password_search_tool`? There are many other programs out there that achieve simliar results to dredge. Dredge solves a few problems that I haven't seen implemented in other tools. 
1. When searching for credentials, it's common to search for the actual password. The obvious problem with this is... what if you don't know the password? Dredge's `context` line allows you to create highly generic queries such as `API_KEY=` and still be able to parse the results for the sensitive information.
2. A wordlist can be tailored to the environment you're running int.
3. Dredge has support for locating and copying kubeconfig files to a log directory for later use.
4. It's just bash. No need for external dependencies. 

# Running Dredge
Running dredge is straightforward but requires some configuration to be useful.

- `dredge.sh`: This is the main shell script to launch dredge.
- `net.txt`: This file contains a list of words dredge will look for on the file system, one per line and they are **CASE SENSITIVE**.
- `kubeconfigs`: This is the directory where identified kubeconfigs will be copied to. 
- `logs`: This is the directory where your scans will be stored. 
    - Initially dredge will create a directory called `logs_baseline`. 
    - A `.log` file will be created for each term listed in `net.txt` if a file is found on the file system matching the search term.
    - After running dredge for the first time, a new log directory will be created inside of `logs` called `logs_new`. All subsequent scans using dredge will be stored in this directory.
    - After reviewing all baseline scans, `dredge -r` can be used to rotate the logs. This will move all logs from `logs_new` to `logs_baseline`. **This will overwrite any logs currently in `logs_baseline`**

## Search mode (-s)
`./dredge.sh -l /home/user -s`

In search mode, dredge will start searching for files at the location provided with the `-l /path/to/search` argument. It will load a wordlist from `net.txt` and output any found words to both STDOUT and `./logs_baseline`if this is the first time running dredge, or  `./logs/logs_new` if a baseline already exists. Additionally, it will print the number of occurances of a given word to STDOUT. 
![image](https://github.com/grahamhelton/dredge/assets/19278569/bd98d27e-489f-4493-ae6f-c1e8c475c55b)

## Logs
Logs produced by dredge are stored in `./logs/`. The goal of the log files are to make it easy to **manually** parse for actual sensitive information. In my experience 99% of the information output by tooling that searches for secrets is noise, but there is no way to know unless you manually look at the files. This is espeically true when casting a wide net by searching for a string such as `aws_access_key_id`. 

Dredge produces a log file containing two lines per match. The first line in the log file is the actual string that was matched from the wordlist. The second line is the "context" line. From experience, the "context" line is necessary because many files contain information where the string being searched for is on one line, and the actual senstive information is on the following line. Utilizing a "context" line below the actual matched content makes for identifying this much easier. It is important to understand that in order to make the log files easily readable, **dredge will truncate a line after 400 bytes**. Please follow up on all truncated lines manually. This is necessary to make log files easily readable.


![image](https://github.com/grahamhelton/dredge/assets/19278569/c5dc2bd3-81ef-4820-b957-5e18d0637aec)

Additionally, logs can be rotated by running `./dredge.sh -r`. This will move the logs from `./logs_new` into `./logs_baseline`


## Kubeconfig mode (-k)
`./dredge.sh -l /home/user -k`

In kubeconfig mode, dredge will start searching for files containing the pattern `kind: config$` (note the `$` which means it will not find configmaps). If a kubeconfig is identified, it will be copied to the `./kubeconfigs` directory and a comment will be appended to the beginning of the file with the pattern `# DREDGE: kubeconfig found in '/path/of/kubeconfig'`

![image](https://github.com/grahamhelton/dredge/assets/19278569/bc9f17e9-578c-4c88-8e4c-a43b52831aed)

# Directory structure
```
.
├── dredge.sh
├── logs
│   ├── logs_baseline       <- Files found on the first run of dredge
│   │   ├── abc123.log      <- File containing all occurances of `abc123`
│   │   ├── password.log
│   │   ├── rockyou.log
│   │   └── secret.log
│   └── logs_new            <- Files found on all other runs of dredge.
│       ├── abc123.log      <- File containing all occurances of `abc123`
│       ├── password.log
│       ├── rockyou.log
│       └── secret.log
├── kubeconfigs             <- Kubeconfig files found
│   └── devconfig           <- Copy of Kubeconfig found on filesystem
│   └── superadmin
├── net.txt                 <- List of words to look for. One per line.
└── README.md

```

# Log file structure 
The log files are structured in a non-standard way to ensure easy manual parsing. The first line that is matched is the line that was matched to a word defined in `net.txt`. The second line is the `context` line. This line is printed to show some additional context around the matched pattern. Often times the matched line is the key in a key/value pair. If no context line is printed, manual review would only show the key, not the value.
```
--
/home/smores/Documents/creds.txt:Password:                             <- Initial matched pattern denoted with a `:` after the file name
/home/smores/Documents/creds.txt- GRAHAMISCOOL_0102#195#!2f            <- context line denoted with a `-` after the file name.
--
```


# Net
Dredge's `net.txt` wordlist is case sensitive by design. Case sensitivity should be handled by changing word case in `net.txt`. For example, If you would like to search the filesystem for both `password` and `Password`, you will need two distinct entries in `net.txt`. This is done to make triage of logs less complex. Although I'm open to a more elegant solution in a PR!  


# Operator Notes
- By default, `html`, `.js`, and `.css` files are ignored to limit the amount of false positives. In my experience these files (especially .js), yeild a lot of noise.
- Dredge will not let you rotate your logs if you haven't run dredge since the last rotation.
- Dredge can take a long time depending on the size of the file system being searched. 
- If you're viewing the logs with [bat](https://github.com/sharkdp/bat), disable color output with: `bat <filename.log> --color=never` 
- Running `comm -1 -3 logs_baseline/<filename.log> logs_new/<filename.log> > diff.txt` will show the different between new and old log files.

# Other projects
Is dredge not what you're looking for? Check out these other cool projects!
- [manspider](https://github.com/blacklanternsecurity/MANSPIDER)
- [Snaffler](https://github.com/SnaffCon/Snaffler)
- [Gobbler](https://github.com/C-Sto/gobbler)
- [Eviltree](https://github.com/t3l3machus/eviltree)
