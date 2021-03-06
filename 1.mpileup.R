## Example:
## qcmd --exec Rscript 1.mpileup.R --config=config.yml --samples=sampleData/20161014_samplesforPSCN.txt

library("aroma.seq")
if (!interactive()) {
  mprint(sessionDetails())
  mprint(findSamtools())
}
options("R.filesets::onRemapping" = "ignore")

message("* Assertions")
ver %<-% attr(findSamtools(), "version")
stopifnot(ver < "1.4")

message("* Loading configuration")
config <- cmdArg(config = "config.yml")
config_data <- yaml::yaml.load_file(config)
str(config_data)

dataset <- cmdArg(dataset = config_data$dataset)
organism <- cmdArg(organism = config_data$organism)
chrs <- cmdArg(chrs = eval(parse(text = config_data$chromosomes)))
samples <- cmdArg(samples = config_data$samples)


## - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Sample data
## - - - - - - - - - - - - - - - - - - - - - - - - - - -
samples <- readDataFrame(samples, fill=TRUE)
o <- order(samples$Patient_ID, samples$Sample_ID)
samples <- samples[o,]
str(samples)


## - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Annotation data
## - - - - - - - - - - - - - - - - - - - - - - - - - - -
message("* Loading annotation data files ...")
fa <- FastaReferenceFile(config_data$fasta)
print(fa)
stopifnot(!isGzipped(fa))
gc <- GcBaseFile(config_data$gcbase)
print(gc)

## IMPORTANT: Sequenza requires that chromosome names in GC file
## and the FASTA file (hg19.fa) need to be identical and in the
## same order.
## PS. It is ok that BAM files are in a different order.
stopifnot(isCompatibleWith(gc, fa))
stopifnot(all(getSeqNames(gc) == getSeqNames(fa)))

message("* Loading annotation data files ... DONE")


## - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Sequence read data
## - - - - - - - - - - - - - - - - - - - - - - - - - - -
message("* Loading all BAM files ...")

dataset <- config_data$dataset
organism <- config_data$organism
bam_pattern <- config_data$bam_pattern
if (is.null(bam_pattern)) bam_pattern <- ".bwa.realigned.rmDups(|.recal)(|.bam)$"
path <- file.path("bamData", dataset, organism)
bams <- BamDataSet$byPath(path, recursive=TRUE, pattern=bam_pattern)
stopifnot(length(bams) > 0)
bams <- bams[grep("old", getPathnames(bams), invert=TRUE)]
stopifnot(length(bams) > 0)
bams <- setFullNamesTranslator(bams, function(name, ...) {
  name <- gsub(".bwa.realigned.rmDups.recal.bam", "", name, fixed=TRUE)
  name <- gsub(".bwa.realigned.rmDups.bam", "", name, fixed=TRUE)
  name <- gsub(".bam", "", name, fixed=TRUE)
  name
})
print(bams)

directoryStructure(bams) <- list(
  pattern="([^/]*)/([^/]*)/([^/]*)/([^/]*)/([^/]*)",
  replacement=c(rootpath="\\1", dataset="\\2", organism="\\3", sample="\\4,\\5")
)


## Keep patients of interest
names <- getNames(bams)
str(names)
tags <- sapply(bams, FUN=function(bam) getTags(bam)[1])
str(tags)
keep <- which(paste(names, tags, sep=",") %in% paste(samples$Patient_ID, samples$A0, sep=","))
str(keep)
stopifnot(length(keep) > 0)
bams <- bams[keep]
print(bams)
stopifnot(length(bams) > 0)

message("* Loading all BAM files ... DONE")


## - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Process
## - - - - - - - - - - - - - - - - - - - - - - - - - - -
if (interactive()) readline("Press ENTER to start processing of data: ")

## - - - - - - - - - - - - - - - - - - - - - - - - - - -
## Count nucleotides at every(!) genomic position
## using 'samtools mpileup'
## - - - - - - - - - - - - - - - - - - - - - - - - - - -
chrLabels <- sprintf("chr%s", chrs)

## Note that the generated *.mpileup files are very large.
res <- mpileup(bams, fa=fa, chromosomes=chrLabels, verbose=-20)
print(res)

mps <- MPileupFileSet(res)
print(mps)

if (!interactive()) {
  mprint(sessionDetails())
  mprint(findSamtools())
}



