# GCP IAM Permissions Reporter
A Ruby script that produces an HTML report for the currently active [GCP](https://cloud.google.com/) project containing:

* A list of [Google Cloud Storage](https://cloud.google.com/storage) buckets and associated IAM roles/members
* A list of [Cloud Pub/Sub](https://cloud.google.com/pubsub) topics and associated IAM roles/members

## Installation
* Ensure that [Ruby](https://www.ruby-lang.org/en/downloads/) is installed. [rbenv](https://github.com/rbenv/rbenv) is a convenient way to manage Ruby installations.

## Running
Run `./gcp-iam-reporter.sh` to generate an HTML report named **<project>-iam-report.html**, where _<project>_ is the name of the current GCP project.

## Copyright
Copyright (C) 2020 Crown Copyright (Office for National Statistics)