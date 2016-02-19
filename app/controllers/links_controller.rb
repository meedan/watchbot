class LinksController < ApplicationController
  respond_to :json

  include LinksDoc

  before_filter :restrict_access

  def bulk_create
    @links = []
    @docs = []
    
    parse_links
    
    begin
      Link.collection.insert_many(@docs)
      @links.map(&:start_watching)
    rescue => e
      # Not all links were inserted (e.g., there was a duplicated one or something)
      Rails.logger.warn "Could not insert all links: #{e.message}"
    end
    
    render_success
  end

  def create
    begin
      render_parameters_missing and return if params[:url].blank?
      Link.create! url: params[:url], application: @key.application
      render_success
    rescue
      render_error 'Could not create link', 'UNKNOWN' 
    end
  end

  def destroy
    begin
      render_parameters_missing and return if params[:url].blank?
      @link = Link.where(url: params[:url], application: @key.application).first
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

  private

  def restrict_access
    authenticate_or_request_with_http_token do |token, options|
      @key = ApiKey.where(access_token: token, expire_at: { :$gte => Time.now }).last
      !@key.nil?
    end
  end

  def parse_links
    params.each do |param, url|
      unless (param =~ /^url/).nil?
        link = Link.new(url: url, application: @key.application)
        @links << link
        @docs << link.as_document
      end
    end
  end
end
