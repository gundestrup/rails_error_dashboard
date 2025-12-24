# frozen_string_literal: true

Rails.application.routes.draw do
  mount RailsErrorDashboard::Engine => '/error_dashboard'
end
