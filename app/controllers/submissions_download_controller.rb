# frozen_string_literal: true

class SubmissionsDownloadController < ApplicationController
  before_action :authenticate_user!
  before_action :load_submitter

  FILES_TTL = 5.minutes

  def index
    authorize! :read, @submitter

    Submissions::EnsureResultGenerated.call(@submitter)

    last_submitter = @submitter.submission.submitters.where.not(completed_at: nil).order(:completed_at).last

    return head :not_found unless last_submitter

    Submissions::EnsureResultGenerated.call(last_submitter)

    if params[:combined] == 'true'
      url = build_combined_url(@submitter)

      if url
        render json: [url]
      else
        head :not_found
      end
    else
      render json: build_urls(last_submitter)
    end
  end

  private

  def load_submitter
    @submitter = Submitter.find_by!(slug: params[:submitter_slug])
  end

  def build_urls(submitter)
    filename_format = AccountConfig.find_or_initialize_by(account_id: submitter.account_id,
                                                          key: AccountConfig::DOCUMENT_FILENAME_FORMAT_KEY)&.value

    Submitters.select_attachments_for_download(submitter).map do |attachment|
      ActiveStorage::Blob.proxy_url(
        attachment.blob,
        expires_at: FILES_TTL.from_now.to_i,
        filename: Submitters.build_document_filename(submitter, attachment.blob, filename_format)
      )
    end
  end

  def build_combined_url(submitter)
    return if submitter.submission.submitters.exists?(completed_at: nil)
    return if submitter.submission.submitters.order(:completed_at).last != submitter

    attachment = submitter.submission.combined_document_attachment
    attachment ||= Submissions::GenerateCombinedAttachment.call(submitter)

    filename_format = AccountConfig.find_or_initialize_by(account_id: submitter.account_id,
                                                          key: AccountConfig::DOCUMENT_FILENAME_FORMAT_KEY)&.value

    ActiveStorage::Blob.proxy_url(
      attachment.blob,
      expires_at: FILES_TTL.from_now.to_i,
      filename: Submitters.build_document_filename(submitter, attachment.blob, filename_format)
    )
  end
end
