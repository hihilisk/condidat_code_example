class ProjectsController < ApplicationController
  before_action :set_project,
                only: %i[show show_without_stats update people history_of_changes timegraph update_sale team_timegraph]

  def index
    projects = policy_scope(Project).order(archived: :asc)
    render json: projects,
           each_serializer: ProjectSerializer,
           adapter: :json
  end

  def show
    authorize @project
    render json: @project, serializer: ProjectStatsSerializer
  end

  def show_without_stats
    authorize @project
    render json: @project, serializer: ProjectSerializer
  end

  def create
    @project = Project.new(project_params)
    @project.platforms = ['inner'] if @project.platforms.blank?
    authorize @project
    if @project.save
      render json: @project, serializer: ProjectSerializer
    else
      render json: @project.errors, status: :unprocessable_entity
    end
  end

  def update
    authorize @project
    if @project.update(project_params)
      render json: @project, serializer: ProjectSerializer
    else
      render json: @project.errors, status: :unprocessable_entity
    end
  end

  # update_sale from ProjectManagementsController
  def update_sale
    authorize @project
    @project.update(manager: User.find(params[:manager_id]))
    render json: @project.manager, serializer: UserShortInfoSerializer
  end

  # people from ProjectManagementsController
  def people
    authorize @project
    render json: @project, include: '*.*', serializer: ProjectPersonSerializer
  end

  def history_of_changes
    authorize @project
    render json: @project.audits.as_json
  end

  def timegraph
    authorize @project
    render json: Projects::TimeGraphService.new(@project, params).members_timegraph
  end

  def team_timegraph
    authorize @project
    render json: Projects::TimeGraphService.new(@project, params).team_timegraph
  end

  def merge_projects
    authorize Project
    service = Projects::MergeService.call(projects_ids: params[:projects_ids], name: params[:name])
    if service.merge
      render json: service.original, serializer: ProjectSerializer
    else
      render json: service.errors, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def common_params
    %i[name title client status project_type link_folder_drive link_channel_discord link_board time_zone
       link_connect_client description]
  end

  def project_params
    params
      .require(:project)
      .permit(
        *common_params, :title, :paid, :archived, :manager_id, :platforms, manager_ids: [], developer_ids: []
      )
  end
end
