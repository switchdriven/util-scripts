#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Show time to go home based on start time
# Calculates end time and overtime based on an 8.5-hour work day
#
# Usage:
#   time-to-go-home.rb [options]
#
# Options:
#   -s, --starttime HH:MM       Start time (default: current time)
#   -r, --referencetime HH:MM   Reference time for overtime calculation (for testing)
#   -o, --overtime              Show overtime
#   -j, --json                  Output as JSON
#   -d, --debug                 Show debug info
#   -h, --help                  Show this help
#

require 'optparse'
require 'json'
require 'time'

WORK_HOURS = 8.5

class WorkTimeCalculator
  def initialize(start_time:, reference_time: nil, overtime: false, json_output: false, debug: false)
    @start_time = start_time
    @reference_time = reference_time
    @overtime = overtime
    @json_output = json_output
    @debug = debug
  end

  def end_time
    @end_time ||= @start_time + (WORK_HOURS * 3600)
  end

  def format_overtime
    now = @reference_time || Time.now
    total_minutes = ((now - end_time) / 60).floor
    sign = total_minutes < 0 ? '-' : ''
    total_minutes = total_minutes.abs
    format('%s%02d:%02d', sign, total_minutes / 60, total_minutes % 60)
  end

  def run
    ot = @overtime ? format_overtime : nil
    now = @reference_time || Time.now

    if @debug
      warn "Start time = #{@start_time.strftime('%H:%M')}, End time = #{end_time.strftime('%H:%M')}, " \
           "Reference time = #{now.strftime('%H:%M')}, Over time = #{ot || '(none)'}"
    end

    if @json_output
      result = {
        'items' => [
          {
            'title'      => 'time to go home',
            'start-time' => @start_time.strftime('%H:%M'),
            'end-time'   => end_time.strftime('%H:%M'),
            'over-time'  => ot
          }
        ]
      }
      puts result.to_json
    elsif @overtime
      puts "EndTime=#{end_time.strftime('%H:%M')}/OverTime=#{ot}"
    else
      puts "EndTime=#{end_time.strftime('%H:%M')}"
    end
  end
end

def parse_hhmm(str, label)
  unless str.match?(/^\d{1,2}:\d{2}$/)
    warn "error: incorrect #{label} format. only 'hh:mm' format is acceptable: #{str}"
    exit 1
  end

  today = Time.now.strftime('%Y-%m-%d')
  Time.strptime("#{today} #{str}", '%Y-%m-%d %H:%M')
end

def main
  options = { starttime: nil, referencetime: nil, overtime: false, json: false, debug: false }

  OptionParser.new do |opts|
    opts.banner = 'Usage: time-to-go-home.rb [options]'

    opts.on('-s', '--starttime HH:MM', 'Start time (default: current time)') do |v|
      options[:starttime] = v
    end

    opts.on('-r', '--referencetime HH:MM', 'Reference time for overtime calculation') do |v|
      options[:referencetime] = v
    end

    opts.on('-o', '--overtime', 'Show overtime') do
      options[:overtime] = true
    end

    opts.on('-j', '--json', 'Output as JSON') do
      options[:json] = true
    end

    opts.on('-d', '--debug', 'Show debug info') do
      options[:debug] = true
    end

    opts.on_tail('-h', '--help', 'Show this help') do
      puts opts
      exit 0
    end
  end.parse!

  start_time = options[:starttime] ? parse_hhmm(options[:starttime], 'starttime') : Time.now
  ref_time   = options[:referencetime] ? parse_hhmm(options[:referencetime], 'referencetime') : nil

  WorkTimeCalculator.new(
    start_time:    start_time,
    reference_time: ref_time,
    overtime:       options[:overtime],
    json_output:    options[:json],
    debug:          options[:debug]
  ).run
end

main if $PROGRAM_NAME == __FILE__
