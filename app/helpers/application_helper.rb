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

  # Durations in minutes offered for units: every 15 minutes from 30 minutes
  # up to 12 hours. Labels use the locale-neutral H:MM format.
  UNIT_DURATION_MINUTES = (30..720).step(15).to_a.freeze

  def unit_duration_options(selected = nil)
    options_for_select(UNIT_DURATION_MINUTES.map { |minutes| [ format_duration(minutes), minutes ] }, selected)
  end

  def format_duration(minutes)
    format("%d:%02d", minutes / 60, minutes % 60)
  end

  # Current length of a unit in minutes when it fits the duration grid.
  def unit_duration_value(unit)
    return nil if unit.starts_at.blank? || unit.ends_at.blank?

    seconds = unit.ends_at - unit.starts_at
    minutes = (seconds / 60).round
    minutes if (seconds % 900).zero? && UNIT_DURATION_MINUTES.include?(minutes)
  end

  UNIT_TIME_OPTIONS = (7..23).flat_map do |hour|
    [ 0, 15, 30, 45 ].map { |minute| format("%02d:%02d", hour, minute) }
  end.freeze

  def unit_time_options(selected = nil)
    list = UNIT_TIME_OPTIONS.dup
    time = selected.to_s
    list.unshift(time) if time.match?(/\A\d{1,2}:\d{2}\z/) && !list.include?(time)
    options_for_select(list.map { |slot| [ slot, slot ] }, selected)
  end

  # [date, "HH:MM"] for the split start fields: submitted values first,
  # otherwise the persisted start rounded to the nearest quarter hour.
  def unit_datetime_parts(unit)
    return [ unit.start_date, unit.start_time ] if unit.start_date.present? || unit.start_time.present?
    return [ "", "" ] if unit.starts_at.blank?

    rounded = Time.zone.at(((unit.starts_at.to_i + 450) / 900) * 900)
    [ rounded.to_date.iso8601, format("%02d:%02d", rounded.hour, rounded.min) ]
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

  def date_badge_class(datetime)
    datetime.present? && datetime >= Time.current ? "badge-success" : "badge-ghost"
  end

  def next_upcoming_unit(program)
    program.units.select { |unit| unit.ends_at.present? && unit.ends_at >= Time.current }.min_by(&:starts_at)
  end

  def format_datetime(datetime)
    return "–" if datetime.blank?

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
