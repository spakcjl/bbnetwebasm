# bbnet 1.2.1

==============

Changes:
* Corrected bbn.predict and bbn.sensitivity due to a bug that caused the functions to fail.

# bbnet 1.2.0

==============

Changes:
* Updated the bbn.predict to allow the storage of model outputs.
* Updated README to show example on how to storage model outputs.
* Modification of bbn.predict and bbn.sensitivity algorithms to more efficiently combine results from multiple inputs nodes.

# bbnet 1.1.0

==============

Changes:
* Updated bbn.predict, bbn.sensitivity, bbn.visualise and bbn.timeseties to allow for zeros in the interaction matrix.
* Updated bbn.sensitivity function to print an error message if spelling of key variables is wrong.
* Updated bbn.visualise and bbn.timeseries to stop function if priors do not follow structure (Increase, Node).
* Updated bbn.predict, bbn.visualise and bbn.timeseties to stop function if the first column of priors does not contain numeric data.
* Updated bbn.predict, bbn.visualise and bbn.timeseties to warn of different ordering of nodes between priors and interaction matrix.

# bbnet 1.0.1

==============

Changes:

* Updated citation section of README.Rmd
* Updated DESCRIPTION file


# bbnet 1.0

bbnet 1.0 (Release date: 13 May 2024)
==============

Changes:

* First version of the package
