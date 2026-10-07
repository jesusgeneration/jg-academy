module ApplicationHelper
  def portal_nav_items
    items = []
    if current_user.staff?
      items << nav_entry(t("layouts.application.nav.dashboard"), dashboard_path)
      items << nav_entry(t("layouts.application.nav.users"), users_path) if policy(User).index?
    else
      items << nav_entry(t("layouts.application.nav.my_account"), user_path(current_user))
    end
    items << nav_entry(t("layouts.application.nav.programs"), programs_path)
    items << nav_entry(t("layouts.application.nav.units"), units_path)
    items << nav_entry(t("layouts.application.nav.organizations"), organizations_path) if policy(Organization).index?
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

  def format_datetime(datetime)
    l(datetime, format: :short)
  end

  def human_enum_label(model_name, attr_name, value)
    I18n.t("activerecord.enums.#{model_name}.#{attr_name}.#{value}", default: value.to_s.humanize)
  end

  def locale_options
    User::LOCALES.map { |code| [ t("languages.#{code}"), code ] }
  end

  def coverage_toggle_button(unit, content, coverages_by_content_id)
    coverage = coverages_by_content_id[content.id]
    if coverage
      button_to t("helpers.coverage.remove"),
        unit_unit_coverage_path(unit, coverage),
        method: :delete,
        form: { class: "inline" },
        class: "btn btn-error btn-outline btn-xs w-20"
    else
      button_to t("helpers.coverage.add"),
        unit_unit_coverages_path(unit),
        params: { unit_coverage: { content_id: content.id } },
        form: { class: "inline" },
        class: "btn btn-outline btn-xs w-20"
    end
  end

  # A row gets no button when an ancestor is covered and the item itself
  # has no direct coverage record (there is nothing to add or remove).
  def coverage_row_button(unit, content, coverages_by_content_id, ancestor_covered: false)
    return nil if ancestor_covered && !coverages_by_content_id.key?(content.id)

    coverage_toggle_button(unit, content, coverages_by_content_id)
  end

  private

  def route_to_controller(path)
    Rails.application.routes.recognize_path(path.split("?").first)[:controller]
  rescue ActionController::RoutingError
    ""
  end
end
