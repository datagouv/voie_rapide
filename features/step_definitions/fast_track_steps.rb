# frozen_string_literal: true

Given('I am on the home page') do
  visit root_path
end

Then('I should see {string}') do |text|
  expect(page).to have_content(text)
end
