# frozen_string_literal: true
class EnvironmentVariableGroupsController < ApplicationController
  before_action :authorize_user!, except: [:index, :show, :preview]
  before_action :group, only: [:show]

  def index
    @groups = EnvironmentVariableGroup.all
    respond_to do |format|
      format.html { @groups }
      format.json { render json: @groups.as_json }
    end
  end

  def new
    render 'form'
  end

  def create
    group.attributes = attributes
    group.save!
    respond_to do |format|
      format.html { redirect_to action: :index }
      format.json { render json: render_group_json(group), status: 201 }
    end
  end

  def show
    respond_to do |format|
      format.html { render 'form' }
      format.json { render json: render_group_json(@group) }
    end
  end

  def update
    group.update_attributes!(attributes)
    redirect_to action: :index
  end

  def destroy
    group.destroy!
    respond_to do |format|
      format.html { redirect_to action: :index }
      format.json { head :no_content }
    end
  end

  def preview
    deploy_groups =
      if deploy_group = params[:deploy_group].presence
        [DeployGroup.find_by_permalink!(deploy_group)]
      else
        DeployGroup.all
      end

    if group_id = params[:group_id]
      @group = EnvironmentVariableGroup.find(group_id)
      @project = Project.new(environment_variable_groups: [@group])
    else
      @project = Project.find(params[:project_id])
    end

    @groups = SamsonEnv.env_groups(@project, deploy_groups, preview: true)

    respond_to do |format|
      format.html
      format.json { render json: {groups: @groups || []} }
    end
  end

  private

  def render_group_json(group)
    group.as_json.tap do |gr|
      gr['environment_variables_attributes'] = render_env_variables(group)
    end
  end

  def render_env_variables(group)
    group.environment_variables.map do |env_var|
      env_var.attributes.slice('id', 'name', 'value')
    end
  end

  def group
    @group ||= if ['new', 'create'].include?(action_name)
      EnvironmentVariableGroup.new
    else
      EnvironmentVariableGroup.find(params[:id])
    end
  end

  def attributes
    params.require(:environment_variable_group).permit(
      :name,
      :comment,
      AcceptsEnvironmentVariables::ASSIGNABLE_ATTRIBUTES
    )
  end

  def authorize_user!
    unauthorized! unless can? :write, :environment_variable_groups, group
  end
end
