class Admin::CommunityMembershipsController < ApplicationController
  before_filter :ensure_is_admin

  def index
    @selected_left_navi_link = "manage_members"
    @community = @current_community
    @memberships = CommunityMembership.where(:community_id => @current_community.id, :status => "accepted")
                                       .includes(:person => :emails)
                                       .paginate(:page => params[:page], :per_page => 50)
                                       .order("#{sort_column} #{sort_direction}")

    respond_to do |format|
      format.html
      format.csv do
        all_memberships = CommunityMembership.where(:community_id => @community.id)
                                              .includes(:person => :emails)
                                              .order("created_at ASC")
        marketplace_name = if @community.use_domain
          @community.domain
        else
          @community.ident
        end
        send_data generate_csv_for(all_memberships), filename: "#{marketplace_name}-users-#{Date.today}.csv"
      end
    end
  end

  def ban
    membership = CommunityMembership.find_by_id(params[:id])

    if membership.person == @current_user
      flash[:error] = t("admin.communities.manage_members.ban_me_error")
      return redirect_to admin_community_community_memberships_path(@current_community)
    end

    membership.update_attributes(:status => "banned")
    membership.update_attributes(:admin => 0) if membership.admin == 1

    @current_community.close_listings_by_author(membership.person)

    redirect_to admin_community_community_memberships_path(@current_community)
  end

  def promote_admin
    if removes_itself?(params[:remove_admin], @current_user, @current_community)
      render nothing: true, status: 405
    else
      @current_community.community_memberships.where(:person_id => params[:add_admin]).update_all("admin = 1")
      @current_community.community_memberships.where(:person_id => params[:remove_admin]).update_all("admin = 0")

      render nothing: true, status: 200
    end
  end

  def posting_allowed
    @current_community.community_memberships.where(:person_id => params[:allowed_to_post]).update_all("can_post_listings = 1")
    @current_community.community_memberships.where(:person_id => params[:disallowed_to_post]).update_all("can_post_listings = 0")

    render nothing: true, status: 200
  end

  def generate_csv_for(memberships)
    CSV.generate(headers: true) do |csv|
      # first line is column names
      csv << %w{
        first_name
        last_name
        username
        joined
        status
        email_address
        email_address_confirmed
        email_from_admins_allowed
        number_of_total_listings
      }
      memberships.each do |membership|
        user = membership.person
        search = {
          author_id: user.id,
          include_closed: true,
          per_page: 9999 # FIXME
        }
        listings = ListingIndexService::API::Api.listings.search(community_id: membership.community.id, search: search, includes: [])
        user_data = [
          user.given_name,
          user.family_name,
          user.username,
          membership.created_at,
          membership.status,
          user.preferences["email_from_admins"],
          listings.data[:count]
        ]
        user.emails.each do |email|
          csv << user_data.insert(5, email.address, !!email.confirmed_at)
        end
      end
    end
  end

  private

  def removes_itself?(ids, current_admin_user, community)
    ids ||= []
    ids.include?(current_admin_user.id) && current_admin_user.is_admin_of?(community)
  end

  def sort_column
    case params[:sort]
    when "name"
      "people.given_name"
    when "email"
      "emails.address"
    when "join_date"
      "created_at"
    when "posting_allowed"
      "can_post_listings"
    else
      "created_at"
    end
  end

  def sort_direction
    #prevents sql injection
    if params[:direction] == "asc"
      "asc"
    else
      "desc" #default
    end
  end

end
