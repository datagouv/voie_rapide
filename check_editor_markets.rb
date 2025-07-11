#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to check markets in the editor app database
# Run this from the voie_rapide_editor_app directory

require 'bundler/setup'
require_relative '../voie_rapide_editor_app/config/environment'

puts '🔍 Checking Editor App Markets Database...'
puts '=' * 50

puts "\n📊 Database Status:"
puts "Total markets: #{Market.count}"
puts "Active markets: #{Market.where(active: true).count}"
puts "Markets with Fast Track ID: #{Market.where.not(fast_track_id: nil).count}"

if Market.any?
  puts "\n📋 All Markets:"
  Market.find_each do |market|
    puts "  • #{market.title}"
    puts "    ID: #{market.id}"
    puts "    Fast Track ID: #{market.fast_track_id || 'NONE'}"
    puts "    Status: #{market.status}"
    puts "    Active: #{market.active?}"
    puts "    Deadline: #{market.deadline&.strftime('%d/%m/%Y à %H:%M') || 'NONE'}"
    puts "    Candidate URL: http://localhost:4000/candidate/#{market.fast_track_id}" if market.fast_track_id
    puts ''
  end
else
  puts "\n❌ No markets found in database!"
  puts "\nTo fix this:"
  puts '1. cd ../voie_rapide_editor_app'
  puts '2. bin/rails db:seed'
  puts '3. Use the generated Fast Track ID for candidate flow testing'
end

puts "\n🎯 Looking for Fast Track ID: d9d14f2cafea6073f88aeb722d96a8f2"
market = Market.find_by(fast_track_id: 'd9d14f2cafea6073f88aeb722d96a8f2')
if market
  puts "✅ FOUND! Market: #{market.title}"
else
  puts '❌ NOT FOUND in editor app database'
  puts "This explains the 'market_not_found' error in the callback"
end
