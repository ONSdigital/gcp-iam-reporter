#!/usr/bin/env ruby

require 'erb'
require 'json'

# Class that generates an HTML report showing the IAM permissions for various GCP services.
class IAMReporter
  DATE_TIME_FORMAT = '%d %b %Y %H:%M'.freeze
  LONDON_REGION    = 'europe-west2'.freeze

  def initialize
    @gcp_project = `gcloud config list --format 'value(core.project)'`
    filename = "#{@gcp_project.rstrip}-iam-report.html"
    write_report(filename,
                 generate_gcs_table_rows_html,
                 generate_pubsub_table_rows_html,
                 generate_cloud_functions_table_rows_html,
                 generate_cloud_run_table_rows_html,
                 generate_dataset_table_rows_html)
  end

  private

  def generate_cloud_functions_table_rows_html
    puts 'Getting Cloud Functions IAM permissions...'
    cloud_functions_table_rows_html = []
    cloud_functions = `gcloud functions list --format 'value(name)'`
    cloud_functions.split("\n").each do |cloud_function|
      permissions_json = JSON.parse(`gcloud functions get-iam-policy #{cloud_function} --region #{LONDON_REGION} --format json`)
      permissions_html = generate_permissions_html(permissions_json)
      table_row_html = "<td class=\"function\">#{cloud_function}</td><td class=\"permissions\">#{permissions_html}</td>"
      cloud_functions_table_rows_html << table_row_html
    end
    cloud_functions_table_rows_html
  end

  def generate_cloud_run_table_rows_html
    puts 'Getting Cloud Run IAM permissions...'
    cloud_run_table_rows_html = []
    cloud_run_services = `gcloud run services list --platform managed --format 'value(name)'`
    cloud_run_services.split("\n").each do |service|
      permissions_json = JSON.parse(`gcloud run services get-iam-policy #{service} --platform managed --region #{LONDON_REGION} --format json`)
      permissions_html = generate_permissions_html(permissions_json)
      table_row_html = "<td class=\"service\">#{service}</td><td class=\"permissions\">#{permissions_html}</td>"
      cloud_run_table_rows_html << table_row_html
    end
    cloud_run_table_rows_html
  end

  def generate_dataset_table_rows_html
    puts 'Getting BigQuery Dataset IAM permissions...'
    dataset_rows_html = []
    datasets = `gcloud alpha bq datasets list --format 'value(datasetReference.datasetId)'`
    datasets.split("\n").each do |dataset|
      permissions_json = JSON.parse(`gcloud alpha bq datasets describe #{dataset} --format json`)
      permissions_html = generate_dataset_permissions_html(permissions_json)
      table_row_html = "<td class=\"dataset\">#{dataset}</td><td class=\"permissions\">#{permissions_html}</td>"
      dataset_rows_html << table_row_html
    end
    dataset_rows_html
  end

  def generate_gcs_table_rows_html
    puts 'Getting GCS IAM permissions...'
    gcs_table_rows_html = []
    buckets = `gsutil ls`
    buckets.split("\n").each do |bucket|
      permissions_json = JSON.parse(`gsutil iam get #{bucket}`)
      permissions_html = generate_permissions_html(permissions_json)
      bucket_name = bucket.gsub('gs://', '').delete_suffix('/')
      gcp_internal = %w[_cloudbuild appspot.com eu.artifacts gcf-sources].any? { |s| bucket_name.include?(s) } ? 'Yes' : 'No'
      table_row_html = "<td class=\"bucket\">#{bucket_name}</td><td class=\"permissions\">#{permissions_html}</td><td>#{gcp_internal}</td>"
      gcs_table_rows_html << table_row_html
    end
    gcs_table_rows_html
  end

  def generate_pubsub_table_rows_html
    puts 'Getting Pub/Sub IAM permissions...'
    pubsub_table_rows_html = []
    topics = `gcloud pubsub topics list | sort`
    topics.split("\n").each do |topic|
      next if topic.start_with?('---')

      topic.gsub!('name: ', '')
      permissions_json = JSON.parse(`gcloud pubsub topics get-iam-policy #{topic} --format json`)
      permissions_html = generate_permissions_html(permissions_json)
      table_row_html = "<td class=\"topic\">#{topic}</td><td class=\"permissions\">#{permissions_html}</td>"
      pubsub_table_rows_html << table_row_html
    end
    pubsub_table_rows_html
  end

  def generate_dataset_permissions_html(permissions_json)
    permissions_html = ''
    if permissions_json.key?('access')
      permissions_json['access'].each do |access|
        permissions_html << "<div class=\"role\">Role: #{access['role'].capitalize}</div><br>"
        if access.key?('specialGroup')
          permissions_html << "<div class=\"member\">Group: #{access['specialGroup']}</div><br>"
        elsif access.key?('userByEmail')
          permissions_html << "<div class=\"member\">User: #{access['userByEmail']}</div><br>"
        end
      end
    else
      permissions_html << '<div class="no-permissions">No explicit permissions assigned (project-level permissions may be being inherited)</div>'
    end
    permissions_html
  end

  def generate_permissions_html(permissions_json)
    permissions_html = ''
    if permissions_json.key?('bindings')
      permissions_json['bindings'].each do |binding|
        permissions_html << "<div class=\"role\">Role: #{binding['role']}</div><br>"
        binding['members'].each { |member| permissions_html << "<div class=\"member\">Member: #{member}</div><br>" }
      end
    else
      permissions_html << '<div class="no-permissions">No explicit permissions assigned (project-level permissions may be being inherited)</div>'
    end
    permissions_html
  end

  def write_report(filename,
                   gcs_table_rows_html,
                   pubsub_table_rows_html,
                   cloud_functions_table_rows_html,
                   cloud_run_table_rows_html,
                   dataset_table_rows_html)
    html = {}
    html['title'] = "IAM Report for #{@gcp_project} (generated #{Time.now.strftime(DATE_TIME_FORMAT)})"
    html['gcs_table_rows']             = gcs_table_rows_html
    html['pubsub_table_rows']          = pubsub_table_rows_html
    html['cloud_functions_table_rows'] = cloud_functions_table_rows_html
    html['cloud_run_table_rows']       = cloud_run_table_rows_html
    html['dataset_table_rows']         = dataset_table_rows_html
    template = './template.erb'
    content = ERB.new(File.read(template)).result(OpenStruct.new(html).instance_eval { binding })
    File.open(filename, 'w') { |f| f.write(content) }
  end
end

IAMReporter.new
