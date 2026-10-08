module ApplicationHelper
  def portal_nav_items
    items = []
    if current_user.staff?
      items << nav_entry("Überblick", dashboard_path)
      items << nav_entry("Benutzer", users_path) if policy(User).index?
    else
      items << nav_entry("Mein Überblick", user_path(current_user))
    end
    items << nav_entry("Kurse", courses_path)
    items << nav_entry("Veranstalter", organizations_path) if policy(Organization).index?
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

  def display_attendance_status(status)
    {
      "registered" => "Angemeldet",
      "attended" => "Teilgenommen",
      "cancelled" => "Abgesagt",
      "no_show" => "Nicht erschienen"
    }.fetch(status.to_s, status.to_s)
  end

  def role_badge_class(role)
    {
      "user" => "badge-ghost",
      "admin" => "badge-primary"
    }.fetch(role.to_s, "badge-ghost")
  end

  def display_role(role)
    {
      "user" => "Benutzer",
      "admin" => "Administrator"
    }.fetch(role.to_s, role.to_s)
  end

  def role_options_for_select
    User.roles.keys.map { |role| [ display_role(role), role ] }
  end

  def membership_role_badge_class(role)
    {
      "member" => "badge-ghost",
      "organiser" => "badge-secondary"
    }.fetch(role.to_s, "badge-ghost")
  end

  def display_membership_role(role)
    {
      "member" => "Mitglied",
      "organiser" => "Organisator"
    }.fetch(role.to_s, role.to_s)
  end

  def display_content_type(content_type)
    {
      "level" => "Ebene",
      "section" => "Bereich",
      "detail" => "Detail"
    }.fetch(content_type.to_s, content_type.to_s)
  end

  def format_datetime(datetime)
    I18n.l(datetime, format: :short)
  end

  def coverage_toggle_button(course, content, coverages_by_content_id)
    coverage = coverages_by_content_id[content.id]
    if coverage
      button_to "Entfernen",
        course_course_coverage_path(course, coverage),
        method: :delete,
        form: { class: "inline" },
        class: "btn btn-error btn-outline btn-xs w-20"
    else
      button_to "Hinzufügen",
        course_course_coverages_path(course),
        params: { course_coverage: { content_id: content.id } },
        form: { class: "inline" },
        class: "btn btn-outline btn-xs w-20"
    end
  end

  # A row gets no button when an ancestor is covered and the item itself
  # has no direct coverage record (there is nothing to add or remove).
  def coverage_row_button(course, content, coverages_by_content_id, ancestor_covered: false)
    return nil if ancestor_covered && !coverages_by_content_id.key?(content.id)

    coverage_toggle_button(course, content, coverages_by_content_id)
  end

  private

  def route_to_controller(path)
    Rails.application.routes.recognize_path(path)[:controller]
  rescue ActionController::RoutingError
    ""
  end
end
