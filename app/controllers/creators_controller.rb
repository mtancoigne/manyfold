class CreatorsController < ApplicationController
  include ModelListable
  include Permittable

  allow_api_access only: [:index, :show], scope: [:read, :public]
  allow_api_access only: [:create, :update], scope: :write
  allow_api_access only: :destroy, scope: :delete

  before_action :get_creator, except: [:index, :new, :create]

  def index
    @models = filtered_models @filters
    @creators = policy_scope(Creator)
    @creators = @creators.where(id: @models.pluck(:creator_id).uniq) unless @filters.empty?

    @tags, @unrelated_tag_count = generate_tag_list(@models, @filter_tags)
    @tags, @kv_tags = split_key_value_tags(@tags)

    # Ordering
    @creators = case session["order"]
    when "recent"
      @creators.order(created_at: :desc)
    else
      @creators.order(name_lower: :asc)
    end

    if helpers.pagination_settings["creators"]
      page = params[:page] || 1
      @creators = @creators.page(page).per(helpers.pagination_settings["per_page"])
    end
    # Eager load data
    @creators = @creators.includes(:links, :collections)
    # Apply tag filters in-place
    @filter_in_place = true

    # Count unassiged models
    @unassigned_count = policy_scope(Model).where(creator: nil).count

    respond_to do |format|
      format.html { render layout: "card_list_page" }
      format.manyfold_api_v0 { render json: ManyfoldApi::V0::CreatorListSerializer.new(@creators).serialize }
    end
  end

  def show
    respond_to do |format|
      format.html do
        @models = policy_scope(Model).where(creator: @creator)
        prepare_model_list
        @additional_filters = {creator: @creator}
        render layout: "card_list_page"
      end
      format.oembed { render json: OEmbed::CreatorSerializer.new(@creator, helpers.oembed_params).serialize }
      format.manyfold_api_v0 { render json: ManyfoldApi::V0::CreatorSerializer.new(@creator).serialize }
    end
  end

  def new
    authorize Creator
    @creator = Creator.new
    @creator.links.build if @creator.links.empty? # populate empty link
    @creator.caber_relations.build if @creator.caber_relations.empty?
    @title = t("creators.general.new")
  end

  def edit
    @creator.links.build if @creator.links.empty? # populate empty link
    @creator.caber_relations.build if @creator.caber_relations.empty?
  end

  def create
    authorize Creator
    @creator = Creator.create(creator_params.merge(Creator.caber_owner(current_user)))
    respond_to do |format|
      format.html do
        if session[:return_after_new]
          redirect_to session[:return_after_new] + "?new_creator=#{@creator.to_param}", notice: t(".success")
          session[:return_after_new] = nil
        else
          redirect_to creators_path, notice: t(".success")
        end
      end
      format.manyfold_api_v0 do
        if @creator.valid?
          render json: ManyfoldApi::V0::CreatorSerializer.new(@creator).serialize, status: :created, location: creator_path(@creator)
        else
          render json: @creator.errors.to_json, status: :bad_request
        end
      end
    end
  end

  def update
    @creator.update(creator_params)
    respond_to do |format|
      format.html do
        if @creator.valid?
          redirect_to @creator, notice: t(".success")
        else
          # Restore previous slug
          @attemped_slug = @creator.slug
          @creator.slug = @creator.slug_was
          render "edit", status: :unprocessable_entity
        end
      end
      format.manyfold_api_v0 do
        if @creator.valid?
          render json: ManyfoldApi::V0::CreatorSerializer.new(@creator).serialize
        else
          render json: @creator.errors.to_json, status: :bad_request
        end
      end
    end
  end

  def destroy
    @creator.destroy
    respond_to do |format|
      format.html { redirect_to creators_path, notice: t(".success") }
      format.manyfold_api_v0 { head :no_content }
    end
  end

  private

  def get_creator
    if params[:id] == "0"
      @creator = nil
      authorize Creator
      @title = t(".unknown")
    else
      @creator = policy_scope(Creator).find_param(params[:id])
      authorize @creator
      @title = @creator.name
    end
  end

  def creator_params
    if is_api_request?
      raise ActionController::BadRequest unless params[:json]
      return ManyfoldApi::V0::CreatorDeserializer.new(params[:json]).deserialize
    end
    params.require(:creator).permit(
      :name,
      :slug,
      :caption,
      :notes,
      links_attributes: [:id, :url, :_destroy]
    ).deep_merge(caber_relations_params(type: :creator))
  end
end
