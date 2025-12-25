class AddSimilarityTrackingToErrorLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :rails_error_dashboard_error_logs, :similarity_score, :float
    add_column :rails_error_dashboard_error_logs, :backtrace_signature, :string

    add_index :rails_error_dashboard_error_logs, :similarity_score
    add_index :rails_error_dashboard_error_logs, :backtrace_signature
  end
end
