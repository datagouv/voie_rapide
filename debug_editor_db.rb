#!/usr/bin/env ruby
# frozen_string_literal: true

# Add the parent directory to load path to access editor app
$LOAD_PATH.unshift(File.expand_path('../', __dir__))

# Set up environment for editor app
ENV['RAILS_ENV'] ||= 'development'

# Manually set up the editor app environment
require 'bundler'
Bundler.setup

# Load the editor app
require File.expand_path('../voie_rapide_editor_app/config/environment', __dir__)

puts '🔍 EDITOR APP DATABASE DEBUG'
puts '=' * 60

begin
  puts "\n📊 Database Connection:"
  puts "Database: #{ActiveRecord::Base.connection.current_database}"
  puts "Tables: #{ActiveRecord::Base.connection.tables.join(', ')}"

  puts "\n📈 Markets Table:"
  puts "Total markets: #{Market.count}"

  if Market.any?
    puts "\n📋 All Markets in Editor App:"
    Market.all.each_with_index do |market, i|
      puts "#{i + 1}. #{market.title}"
      puts "   ID: #{market.id}"
      puts "   Fast Track ID: #{market.fast_track_id || 'NULL'}"
      puts "   Status: #{market.status}"
      puts "   Active: #{market.active}"
      puts "   Created: #{market.created_at}"
      puts "   Updated: #{market.updated_at}"
      puts "   Deadline: #{market.deadline || 'NULL'}"
      puts ''
    end

    puts "\n🎯 Searching for Fast Track ID: d9d14f2cafea6073f88aeb722d96a8f2"
    target_market = Market.find_by(fast_track_id: 'd9d14f2cafea6073f88aeb722d96a8f2')

    if target_market
      puts '✅ FOUND!'
      puts "   Market: #{target_market.title}"
      puts "   Status: #{target_market.status}"
      puts "   Active: #{target_market.active}"
    else
      puts '❌ NOT FOUND'
      puts "\n📋 Available Fast Track IDs:"
      Market.where.not(fast_track_id: nil).find_each do |market|
        puts "   • #{market.fast_track_id} (#{market.title})"
      end

      puts '   (No markets have Fast Track IDs assigned)' if Market.where.not(fast_track_id: nil).empty?
    end
  else
    puts '❌ No markets found in database!'
    puts "\n💡 This could mean:"
    puts '   1. Database not seeded'
    puts '   2. Buyer flow callback failed'
    puts '   3. Database connection issue'
  end
rescue StandardError => e
  puts "❌ ERROR: #{e.message}"
  puts 'Backtrace:'
  puts e.backtrace.join("\n")
end
