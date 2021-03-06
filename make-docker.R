#!/usr/bin/env Rscript
# ----------------------------------------------------------------------------
# R Skript - (W) by N. Markgraf in 2021
# ----------------------------------------------------------------------------
# DEBUG <- FALSE
DEBUG <- TRUE

# Paket zum Umgang mit GitHub Repositoies
library(git2r)

# Alternative zu git2r
library(gert)
library(credentials)

# Paket zum Parsen von Parametern
library(optparse)

option_list = list(
    make_option(c("-u", "--username"),
                type = "character",
                default = NULL,
                help = "Benutzername GitHub",
                metavar = "character"),
    make_option(c("-p", "--password"),
                type = "character",
                default = NULL,
                help = "Passwort für den GitHub Account",
                metavar = "character"),
    make_option(c("-k", "--sshkey"),
                type = "character",
                default = NULL,
                help = "ssh-private-key für den GitHub Account",
                metavar = "character"),
    make_option(c("-K", "--sshkeypub"),
                type = "character",
                default = NULL,
                help = "ssh-public-key für den GitHub Account",
                metavar = "character"),
    make_option(c("-r", "--repourl"),
                type = "character",
                default = "https://github.com/FOM-ifes/VL-Vorlesungsfolien.git",
                # default = "https://github.com/NMarkgraf/MathGrundDer-W-Info.git",
                help = "URL zum Repository [default= %default]",
                metavar = "character"),
    make_option(c("-n", "--name"),
                type = "character",
                default = "Vorlesungen",
                help = "Name des Repository [default= %default]",
                metavar = "character"),
    make_option(c("-m", "--modul"),
                type = "character",
                default = "Wissenschaftliche-Methodik",
                help = "Name des zu erstellenden Modul Skriptes [default= %default]",
                metavar = "character")
);

opt_parser <- OptionParser(option_list=option_list);
opt <- parse_args(opt_parser);

#### DEBUG ####
if (DEBUG) {
  print("DEBUG: Aufrufinformationen")
  if (!is.null(opt$username)) {
    print(paste0("--username=", opt$username))
  }
  if (!is.null(opt$password)) {
    print(paste0("--password=", "**********"))
  }
  
  if (!is.null(opt$repourl)) {
    print(paste0("--repourl=", opt$repourl))
  }
  if (!is.null(opt$name)) {
    print(paste0("--name=", opt$name))
  }
  if (!is.null(opt$modul)) {
    print(paste0("--modul=", opt$modul))
  }
}

####-------####

modul_name <- paste0(opt$modul)
print(paste("Setze Modulename auf", opt$modul))
print(paste("Setze Modulename auf", modul_name))

# default:
username <- NULL
password <- NULL
if (!is.null(opt$username)) {
  username <- opt$username
}
if (!is.null(opt$username)) {
  password <- opt$password
}

cred <- NULL

# Setzen der Zugangsdaten (falls nötig/möglich)
if (!is.null(username)) {
  if (!is.null(password)) {
    cred <- cred_user_pass(username = username, password = password)
  } else {
    cred <- cred_user_pass(username = username)
  }
} else {
  cred <- NULL
}

repo_name <- opt$name
repo_url <- opt$repourl

# Lade das Repository "Vorlesungen" von GitHub

## Create a temporary directory to hold the repository
# path <- file.path(tempfile(pattern="git2r-"), repo_name)

# Verzeichnis anlegen in welches das Ropsiory geclont wird:
repo_path <- file.path("/home/Vorlesungen", repo_name)
dir.create(repo_path, recursive = TRUE)


if (!is.null(opt$sshkey)) {
  if (DEBUG) { print("### 0 ###") }
  fileConn <- file("./temp_ssh_key")
  writeLines(opt$sshkey, fileConn)
  close(fileConn)
  fileConn <- file("./temp_ssh_key.pub")
  writeLines(opt$sshkeypub, fileConn)
  close(fileConn)

  if (DEBUG) { print("### 1 ###") }
  f <- list.files("./temp_ssh_key", all.files = TRUE, full.names = TRUE, recursive = TRUE)
  Sys.chmod(f, (file.info(f)$mode | "600"))
  f <- list.files("./temp_ssh_key.pub", all.files = TRUE, full.names = TRUE, recursive = TRUE)
  Sys.chmod(f, (file.info(f)$mode | "644"))
  # file.show("./temp_ssh_key")
  # file.show("./temp_ssh_key.pub")
  if (DEBUG) { print(libgit2_features()) }
  
  if (DEBUG) { print("### 2 ###") }
  cred <- cred_ssh_key("./temp_ssh_key.pub", "./temp_ssh_key")
  if (DEBUG) { print(cred) }
  
  if (DEBUG) { print("### 3 ###") }
  
  #repo <- clone(url = repo_url,
  #              local_path = repo_path, 
  #              credentials = cred)
  system(paste("/home/Vorlesungen/git-clone.sh", repo_url, repo_path))
} else {
  ## Clone the git2r repository
  repo <- clone(url = repo_url,
                local_path = repo_path, 
                credentials = cred)
}



# In das geklonte Verzeichnis wechseln
setwd(repo_path)

# Zuerst das "RunMeFirst.R" starten, damit alle weiteren Pakete
# installiert werden
print("Prüfe ob RunMeFirst.R gestartet werden kann!")
if (file.exists("RunMeFirst.R")) {
  print("Starte RunMeFirst.R:")
  #-- Leider überschreibt "source(..)" alle lokalen Variabeln.
  # source("RunMeFirst.R", local=TRUE)
  #-- daher:
  ee <- new.env()
  sys.source('RunMeFirst.R', ee)
}

print("Pandoc-Filter mit korrekten Zugriffsrechten ausstatten!")
f <- list.files("pandoc-filter/*.py", all.files = TRUE, full.names = TRUE, recursive = TRUE)
Sys.chmod(f, (file.info(f)$mode | "777"))

# Den eigentlichen render-Prozess starten:
print("Prüfe makerender.R Optionen!")
if (exists("modul_name")) {
  if (!is.null(modul_name)) {
    if (DEBUG) {
      print(paste("makerender.R Optione:", modul_name))
    }
    commandArgs <- function(...) list(modul_name)
  }
} else {
  print("Oops: modul_name fehlt!")
}

print("Starte makerender.R:")

source("makerender.R")

# Ergebnisse in "results" kopieren

dir_list <- list.files(".", ".pdf$")

results_path <- "/home/Vorlesungen/results"

for (pdf in dir_list) {
  file.copy(from = pdf,
            to = results_path,
            overwrite = TRUE,
            recursive = FALSE,
            copy.mode = TRUE,
            copy.date = TRUE)
}

# Alle Log-dateien ebenfalls kopieren

results_log_path <- file.path(results_path, "log")
dir.create(results_log_path, recursive = TRUE)
dir_list <- list.files(".", ".log$", recursive = TRUE)

for (log in dir_list) {
  file.copy(from = log,
            to = results_log_path,
            overwrite = TRUE,
            recursive = FALSE,
            copy.mode = TRUE,
            copy.date = TRUE)
}
