SAMPLES = ["9T","9B"]
dir = "/home/UTHSCSA/huelgasmoral/Documents/"

rule all:
  input: directory("db"),
         "{dir}WES/Analysis/calls/all.vcf"


rule genomics_db_import:
    input:
        gvcfs=["/home/UTHSCSA/huelgasmoral/Documents/WES/Analysis/calls/9T.g.vcf",
        "/home/UTHSCSA/huelgasmoral/Documents/WES/Analysis/calls/9B.g.vcf"]
    output:
        db=directory("db"),
    log:
        "{dir}WES/Analysis/logs/gatk/genomicsdbimport.log"
    params:
        intervals="",
        db_action="create", # optional
        extra="",  # optional
        java_opts="",  # optional
    resources:
        mem_mb=6000
    wrapper:
        "0.80.2/bio/gatk/genomicsdbimport"

rule genotype_gvcfs:
    input:
        gvcf="gendb://db",  # combined gvcf over multiple samples
    # N.B. gvcf or genomicsdb must be specified
    # in the latter case, this is a GenomicsDB data store
        ref="{dir}Reference/Homo_sapiens_assembly38.fasta"
    output:
        vcf="{dir}WES/Analysis/calls/all.vcf",
    log:
        "{dir}WES/Analysis/logs/gatk/genotypegvcfs.log"
    params:
        extra="",  # optional
        java_opts="", # optional
    resources:
        mem_mb=6000
    wrapper:
        "0.80.2/bio/gatk/genotypegvcfs"
