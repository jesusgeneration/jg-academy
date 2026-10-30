module ApplicationHelper
  # Training-hours goal (100%) for user progress, in hours.
  USER_TRAINING_HOURS_GOAL = 50
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

  # A row with ancestor coverage and no direct record shows a disabled
  # button in the "added" look: descendants are covered via the ancestor,
  # so there is nothing to add or remove on the row itself.
  def coverage_row_button(unit, content, coverages_by_content_id, ancestor_covered: false, via_title: nil)
    if ancestor_covered && !coverages_by_content_id.key?(content.id)
      hint = via_title ? t("units.show.covered_via", title: via_title) : nil
      return button_tag(t("helpers.coverage.remove"),
        disabled: true,
        class: "btn btn-error btn-outline btn-xs w-20",
        title: hint)
    end

    coverage_toggle_button(unit, content, coverages_by_content_id)
  end

  # Fraction of a section's details covered by the unit (0.0-1.0).
  # Direct section coverage or an ancestor level coverage counts as complete.
  def section_coverage_fraction(section, coverages_by_content_id, ancestor_covered: false)
    return 1.0 if ancestor_covered || coverages_by_content_id.key?(section.id)

    details = section.children.to_a
    return 0.0 if details.empty?

    covered = details.count { |detail| coverages_by_content_id.key?(detail.id) }
    covered.to_f / details.size
  end

  # Fraction of a level's sections covered by the unit (0.0-1.0).
  # A fully covered section scores 1.0, a section with at least one
  # covered detail scores 0.5, otherwise 0.0. Direct level coverage
  # counts as complete.
  def level_coverage_fraction(level, coverages_by_content_id)
    return 1.0 if coverages_by_content_id.key?(level.id)

    sections = level.children.to_a
    return 0.0 if sections.empty?

    total = sections.sum do |section|
      if coverages_by_content_id.key?(section.id)
        1.0
      else
        details = section.children.to_a
        if details.empty?
          0.0
        else
          covered = details.count { |detail| coverages_by_content_id.key?(detail.id) }
          if covered == details.size
            1.0
          elsif covered.positive?
            0.5
          else
            0.0
          end
        end
      end
    end
    total / sections.size
  end

  # Whether a detail counts as covered: directly, or via its section
  # or level ancestor.
  def detail_covered?(detail, coverages_by_content_id, ancestor_covered: false)
    ancestor_covered || coverages_by_content_id.key?(detail.id)
  end

  # User progress for a topic: [covered details, total details] as a pure
  # detail ratio. Direct topic coverage or an ancestor topic-area coverage
  # counts all details as covered. Topics without details (e.g. the
  # Pflichtkurse check-offs) are binary instead: only a direct link on the
  # topic itself counts as covered ([1, 1]); an ancestor level link does
  # not fulfill them, so they stay ([0, 1]).
  def user_topic_progress(section, covered_ids, ancestor_covered: false)
    details = section.children.to_a
    if details.empty?
      return covered_ids.include?(section.id) ? [ 1, 1 ] : [ 0, 1 ]
    end
    return [ details.size, details.size ] if ancestor_covered || covered_ids.include?(section.id)

    [ details.count { |detail| covered_ids.include?(detail.id) }, details.size ]
  end

  # User progress for a topic area: [covered details, total details] as a
  # pure detail ratio across all its topics. No partial-topic weighting.
  # Topics without details count as one binary item each (covered only via
  # a direct link). A topic area holding only such topics (e.g.
  # Pflichtkurse) therefore shows [covered topics, total topics], and a
  # direct level link alone fulfills nothing there.
  def user_topic_area_progress(level, covered_ids)
    sections = level.children.to_a
    children_by_section = sections.to_h { |section| [ section, section.children.to_a ] }
    details = children_by_section.values.flatten
    bare_sections = sections.select { |section| children_by_section[section].empty? }

    if details.empty?
      covered = sections.count { |section| covered_ids.include?(section.id) }
      return [ covered, sections.size ]
    end

    total = details.size + bare_sections.size
    return [ total, total ] if covered_ids.include?(level.id)

    covered = sections.sum do |section|
      section_details = children_by_section[section]
      if section_details.empty?
        covered_ids.include?(section.id) ? 1 : 0
      elsif covered_ids.include?(section.id)
        section_details.size
      else
        section_details.count { |detail| covered_ids.include?(detail.id) }
      end
    end
    [ covered, total ]
  end

  # Number of distinct details a unit covers, inherited links included.
  def unit_detail_coverage_count(unit, coverages_by_unit_id, detail_map)
    coverages = coverages_by_unit_id[unit.id] || []
    coverages.flat_map { |coverage| detail_map[coverage.content_id] || [] }.uniq.size
  end

  # Builds a sortable column header link. Keeps the current query params
  # (e.g. the tab) and toggles the direction on repeat clicks; the first
  # click sorts ascending. The active column shows an arrow indicator.
  def sort_link(key, label)
    key = key.to_s
    current_direction = params[:direction].to_s == "desc" ? "desc" : "asc"
    active = params[:sort].to_s == key
    direction = active && current_direction == "asc" ? "desc" : "asc"
    indicator = active ? (current_direction == "desc" ? " ▼" : " ▲") : ""
    query = request.query_parameters.merge(sort: key, direction: direction).to_query
    link_to "#{label}#{indicator}", "?#{query}", class: "link link-hover"
  end

  # Percent (0-100) for a covered/total pair; empty totals show 0%.
  def user_progress_percent(covered, total)
    return 0 if total.zero?

    [ (covered.to_f / total * 100).round, 100 ].min
  end

  # Percent (0-100) of training hours toward the goal; capped at 100%.
  def training_hours_percent(hours, goal = USER_TRAINING_HOURS_GOAL)
    return 0 if goal.to_f <= 0

    [ (hours.to_f / goal * 100).round, 100 ].min
  end

  # Content-type badge with a progress-bar style fill for coverage.
  # Uncovered items keep the plain badge look; anything covered
  # (partial or complete) gets a proportional fill. Details are binary.
  def coverage_progress_badge(content, fraction)
    label = human_enum_label("content", "content_type", content.content_type)
    base_class = case content.content_type
    when "level" then "badge badge-primary badge-outline badge-sm mr-1"
    when "section" then "badge badge-secondary badge-outline badge-sm mr-1"
    else "badge badge-ghost badge-sm mr-1"
    end
    return content_tag(:span, label, class: base_class) if fraction <= 0.0

    percent = [ (fraction * 100).round, 100 ].min
    fill = case content.content_type
    when "level" then "var(--color-primary)"
    when "section" then "var(--color-secondary)"
    else "var(--color-neutral)"
    end
    style = "background: linear-gradient(to right, " \
      "color-mix(in oklab, #{fill} 30%, transparent) #{percent}%, transparent #{percent}%)"
    hint = t("units.show.coverage_progress", percent: percent)
    content_tag(:span, label, class: base_class, style: style, title: hint, aria: { label: hint })
  end

  private

  def route_to_controller(path)
    Rails.application.routes.recognize_path(path.split("?").first)[:controller]
  rescue ActionController::RoutingError
    ""
  end
end
