# RSF - RNA Structure Framework (v1.0.0a)

The recent advent of high-throughput methods for probing RNA secondary structures has enabled for the transcriptome-wide analysis of the RNA structurome. Despite the establishment of several methods for querying RNA secondary structures on a genome-wide scale (CIRS-seq, SHAPE-seq, Structure-seq, PARS), no tool has been developed to date to enable the rapid analysis and interpretation of these data. 

The RNA Structure Framework is a modular toolkit developed to deal with RNA structure probing high-throughput data, from reads mapping to structure inference. Its main features are: 

- Automatic reference transcriptome creation
- Automatic reads preprocessing (adapter clipping and trimming) and mapping
- Scoring and data normalization
- Accurate RNA folding prediction by incorporating structural probing data

For updates, please visit: https://rsf.hugef-research.org
For support, post your questions to: https://groups.google.com/forum/#!forum/rsftoolkit


## Author

Danny Incarnato (danny.incarnato[at]hugef-torino.org)
Epigenetics Unit @ HuGeF [Human Genetics Foundation]
Group leader: Prof. Salvatore Oliviero (salvatore.oliviero[at]hugef-torino.org


## Citation

Incarnato *et al*., (2015) RNA structure framework: automated transcriptome-wide reconstruction of RNA secondary structures from high-throughput structure probing data.


## License

This program is free software, and can be redistribute and/or modified under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.

Please see http://www.gnu.org/licenses/ for more informations.


## Prerequisites

- Linux/Mac system
- Bowtie v1.0.0 (http://bowtie-bio.sourceforge.net/index.shtml)
- SAMTools v1.2 or greater (http://www.htslib.org/)
- BEDTools v2.0 or greater (https://github.com/arq5x/bedtools2/)
- FASTX Toolkit (http://hannonlab.cshl.edu/fastx_toolkit/)
- ViennaRNA Package v2.2.0 or greater (http://www.tbi.univie.ac.at/RNA/)
- RNAstructure v5.6 or greater (http://rna.urmc.rochester.edu/RNAstructure.html)
- Perl v5.12 (or greater), with ithreads support
- Perl non-CORE modules (http://search.cpan.org/):

    ¥ DBI
    ¥ LWP::UserAgent
    ¥ RNA (part of the ViennaRNA package)
    ¥ XML::Simple


## Installation

Clone RSF git repository:
```bash
git clone https://github.com/dincarnato/RSF
```
This will create a RSF folder.
To add RSF executables to your PATH, simply type:
```bash
export PATH=$PATH:/path/to/RSF
```

## Usage

Please refer to the RSF Manual.
To obtain parameters list, simply call the required program with the "-h" (or "--help") parameter.