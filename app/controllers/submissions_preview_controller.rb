# frozen_string_literal: true

class SubmissionsPreviewController < ApplicationController
  around_action :with_browser_locale
  prepend_before_action :maybe_redirect_com, only: %i[show completed]
  before_action :authenticate_user!
  before_action :load_submission

  def show
    authorize! :read, @submission

    @submission = Submissions.preload_with_pages(@submission)

    render 'submissions/show', layout: 'plain'
  end

  def completed
    authorize! :read, @submission
    @template = @submission.template

    render :completed, layout: 'form'
  end

  private

  def load_submission
    @submission = Submission.find_by!(slug: params[:slug] || params[:submissions_preview_slug])
  end
end
