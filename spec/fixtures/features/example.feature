Feature: Sign in flow
  As a visitor
  I want to sign in
  So that I can see my dashboard

  Background:
    Given the database is seeded

  @auth
  Scenario: Visitor signs in
    Given the user logs in
    Then they are redirected to the dashboard
