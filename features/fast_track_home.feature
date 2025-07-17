# frozen_string_literal: true

Feature: Fast Track Home Page
  As a user visiting the Fast Track application
  I want to see the home page
  So that I can confirm the application is working

  Scenario: User visits the home page
    Given I am on the home page
    Then I should see "Voie Rapide - Fast Track"
    And I should see "Fast Track test page is working!"
    And I should see "foundation for our Fast Track procurement application"

  Scenario: User sees DSFR French government design
    Given I am on the home page
    Then I should see "République"
    And I should see "Française"
    And I should see "Simplifiez vos candidatures aux marchés publics"
    And I should see "Bienvenue sur Voie Rapide"