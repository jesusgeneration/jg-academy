module ApplicationHelper
  def portal_nav_items
    items = []
    if current_user.staff?
      items << nav_entry("Dashboard", dashboard_path)
      items << nav_entry("Users", users_path) if policy(User).index?
    else
      items << nav_entry("My Progress", user_path(current_user))
    end
    items << nav_entry("Courses", courses_path)
    items << nav_entry("Juleica Requirements", juleica_requirements_path) if policy(JuleicaRequirement).index?
    items << nav_entry("Organizations", organizations_path) if policy(Organization).index?
    items
  end

  def nav_entry(label, path)
    { label: label, path: path, active: controller_path == route_to_controller(path) }
  end

  def flash_class(type)
    case type.to_s
    when "notice" then "alert-success"
    when "alert" then "alert-error"
    else "alert-info"
    end
  end

  def attendance_status_badge_class(status)
    {
      "registered" => "badge-info",
      "attended" => "badge-success",
      "cancelled" => "badge-warning",
      "no_show" => "badge-error"
    }.fetch(status.to_s, "badge-ghost")
  end

  def role_badge_class(role)
    {
      "user" => "badge-ghost",
      "admin" => "badge-primary"
    }.fetch(role.to_s, "badge-ghost")
  end

  def membership_role_badge_class(role)
    {
      "member" => "badge-ghost",
      "organiser" => "badge-secondary"
    }.fetch(role.to_s, "badge-ghost")
  end

  def requirement_status_badge(result)
    if result.completed?
      [ "badge-success", "Complete" ]
    elsif result.partial?
      [ "badge-warning", "In progress" ]
    else
      [ "badge-ghost", "Not started" ]
    end
  end

  def progress_percent(result)
    return 100 if result.completed?

    ((result.earned_hours / result.required_hours) * 100).clamp(0, 100)
  end

  def format_hours(hours)
    number_with_precision(hours, precision: 2, strip_insignificant_zeros: true)
  end

  def format_datetime(datetime)
    datetime.strftime("%d %b %Y, %H:%M")
  end

  private

  def route_to_controller(path)
    Rails.application.routes.recognize_path(path)[:controller]
  rescue ActionController::RoutingError
    ""
  end
end
