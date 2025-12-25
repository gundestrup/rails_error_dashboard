class AddEnhancedMetricsToErrorLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :rails_error_dashboard_error_logs, :app_version, :string
    add_column :rails_error_dashboard_error_logs, :git_sha, :string
    add_column :rails_error_dashboard_error_logs, :priority_score, :integer

    # Indexes for enhanced metrics
    add_index :rails_error_dashboard_error_logs, :app_version
    add_index :rails_error_dashboard_error_logs, :git_sha
    add_index :rails_error_dashboard_error_logs, :priority_score
  end
end
