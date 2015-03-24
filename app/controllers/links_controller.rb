class LinksController < ApplicationController
  respond_to :json

  def create
    begin
      render_parameters_missing and return if params[:url].blank?
      Link.create! url: params[:url]
      render_success
    rescue
      render_error 'Could not create link', 'UNKNOWN' 
    end
  end

  def destroy
    begin
      render_parameters_missing and return if params[:id].blank?
      @link = Link.where(url: params[:id]).first
      if @link.nil?
        render_not_found
      else
        @link.destroy!
        render_success
      end
    rescue
      render_error 'Could not delete link', 'UNKNOWN' 
    end
  end
end
