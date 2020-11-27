#!/usr/bin/env ruby

require 'erb'
require 'json'

# Class that generates an HTML report showing GCS and Pub/Sub IAM permissions.
class IAMReporter
  DATE_TIME_FORMAT = '%d %b %Y %H:%M'.freeze

  def initialize
    @gcp_project = `gcloud config list --format 'value(core.project)'`
    filename = "#{@gcp_project.rstrip}-iam-report.html"
    write_report(filename, generate_gcs_table_rows_html, generate_pubsub_table_rows_html)
  end

  private

  def generate_gcs_table_rows_html
    puts 'Getting GCS IAM permissions...'
    gcs_table_rows_html = []
    buckets = `gsutil ls`
    buckets.split("\n").each do |bucket|
      permissions_json = JSON.parse(`gsutil iam get #{bucket}`)
      permissions_html = generate_permissions_html(permissions_json)
      bucket_name = bucket.gsub('gs://', '').delete_suffix('/')
      gcp_internal = %w(_cloudbuild appspot.com eu.artifacts gcf-sources).any? { |s| bucket_name.include?(s) } ? 'Yes' : 'No'
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

  def generate_permissions_html(permissions_json)
    permissions_html = ''
    if permissions_json.key?('bindings')
      permissions_json['bindings'].each do |binding|
        permissions_html << "<div class=\"role\">Role: #{binding['role']}</div><br>"
        binding['members'].each { |member| permissions_html << "<div class=\"member\">Member: #{member}</div><br>" }
      end
    else
      permissions_html << '<div>No permissions assigned</div>'
    end
    permissions_html
  end

  def write_report(filename, gcs_table_rows_html, pubsub_table_rows_html)
    html = {}
    html['title'] = "IAM Report for #{@gcp_project} (generated #{Time.now.strftime(DATE_TIME_FORMAT)})"
    html['gcs_table_rows']    = gcs_table_rows_html
    html['pubsub_table_rows'] = pubsub_table_rows_html
    template = './template.erb'
    content = ERB.new(File.read(template)).result(OpenStruct.new(html).instance_eval { binding })
    File.open(filename, 'w') { |f| f.write(content) }
  end
end

IAMReporter.new
