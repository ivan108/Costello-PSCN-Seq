library("aroma.seq")
library("PSCBS")
if (!interactive()) mprint(sessionDetails())
library("listenv")
source("R/pairs_from_samples.R")
source("R/utils.R")

## USAGE:
## qcmd --exec Rscript 4.reports.R --config=config.yml --samples=sampleData/20161014_samplesforPSCN.txt

mprintf("Script: 4.reports.R ...\n")


message("* Loading configuration")
config <- cmdArg(config = "config.yml")
config_data <- yaml::yaml.load_file(config)
str(config_data)

dataset <- cmdArg(dataset = config_data$dataset)
organism <- cmdArg(organism = config_data$organism)
chrs <- cmdArg(chrs = eval(parse(text = config_data$chromosomes)))
samples <- cmdArg(samples = config_data$samples)


## - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Annotation data
## - - - - - - - - - - - - - - - - - - - - - - - - - - -
mprintf("Dataset: %s\n", dataset)
mprintf("Organism: %s\n", organism)
chrs[chrs == "X"] <- 23
chrs[chrs == "Y"] <- 24
chrs[chrs == "M"] <- 25
mprintf("Chromosomes: %s\n", seqToHumanReadable(chrs))



## - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Sample data
## - - - - - - - - - - - - - - - - - - - - - - - - - - -
if (samples != "*") {
  ## Tumor-normal pairs from sample data
  data <- readDataFrame(samples, fill=TRUE)
  pairs <- pairs_from_samples(data)
  mstr(pairs)
}


## - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Identify files to be processed
## - - - - - - - - - - - - - - - - - - - - - - - - - - -
datasetS <- paste(c(dataset, "seqz,100kb,tcn=2"), collapse = ",")
pathS <- file.path("pscbsData", datasetS, organism)
pathS <- Arguments$getReadablePath(pathS)
pathnamesS <- dir(path=pathS, pattern=",PairedPSCBS.rds", full.names=TRUE)
## Sanity check
if (length(pathnamesS) == 0) {
  stop("Failed to locate any *,PairedPSCBS.rds files: ", sQuote(pathS))
}

all_samples <- gsub(",chrs=.*", "", basename(pathnamesS))
filenamesD <- sprintf("%s,PairedPSCBS,report.pdf", all_samples)
studyName <- datasetS
pathD <- file.path("reports", studyName)
pathnamesD <- file.path(pathD, filenamesD)

todo <- which(!file_test("-f", pathnamesD))
if (length(todo) == 0) {
  mprintf("There exist a PDF report for all %d samples: %s\n", length(pathnamesS), pathD)
}

## Keep non-processed files
if (length(todo) != length(pathnamesD)) {
  all_samples <- all_samples[todo]
  pathnamesS <- pathnamesS[todo]
  pathnamesD <- pathnamesD[todo]
}


if (FALSE && samples != "*") {
  stop("Not yet implemented")
  sample_pairs <- sprintf("%s,%s_vs_%s", pairs$Patient_ID, pairs$T.A0, pairs$N.A0)
  missing <- sample_pairs[!(sample_pairs %in% samples)]
  if (length(missing) > 0) {
    warning(sprintf("Sequenza files not available for %d tumor-normal pairs: %s", length(missing), hpaste(sQuote(missing))))
  }
  all_samples <- intersect(sample_pairs, all_samples)
}

mprintf("Tumor-normal samples: [n=%d] %s\n", length(all_samples), hpaste(sQuote(all_samples)))


## - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Process
## - - - - - - - - - - - - - - - - - - - - - - - - - - -
if (interactive()) readline("Press ENTER to start processing of data: ")


reports <- listenv()
for (ii in seq_along(all_samples)) {
  sample <- all_samples[ii]
  verbose && enterf(verbose, "Sample %d ('%s') of %d ...\n", ii, sample, length(all_samples))

  pathnameS <- pathnamesS[ii]
  pathnameD <- pathnamesD[ii]

  ## Nothing to do?
  if (isFile(pathnameD)) {
    verbose && cat(verbose, "Already processed. Skipping")
    reports[[ii]] <- pathnameD
    next
  }

  label <- sprintf("sample_%d_%s", ii, sample)
  reports[[ii]] %<-% {
    fit <- loadObject(pathnameS)
    pdf <- report(fit, studyName=studyName)
    unclass(pdf)
  } %label% label

  ## Have at most 10 jobs on the cluster at any time
  if (ii %% 10 == 0) resolve(reports)
  verbose && exit(verbose)
} ## for (ii ...)

reports <- unlist(reports)
print(reports)

if (!interactive()) mprint(sessionDetails())
