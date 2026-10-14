require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#section_coverage_fraction" do
    it "returns one third when one of three details is covered" do
      section = create(:content, :section)
      details = create_list(:content, 3, :detail, parent: section)
      coverages = { details.first.id => instance_double(UnitCoverage) }

      expect(helper.section_coverage_fraction(section, coverages)).to be_within(0.001).of(1.0 / 3)
    end

    it "returns complete for direct section coverage" do
      section = create(:content, :section)
      create_list(:content, 3, :detail, parent: section)
      coverages = { section.id => instance_double(UnitCoverage) }

      expect(helper.section_coverage_fraction(section, coverages)).to eq(1.0)
    end

    it "returns complete when an ancestor level is covered" do
      section = create(:content, :section)
      create_list(:content, 2, :detail, parent: section)

      expect(helper.section_coverage_fraction(section, {}, ancestor_covered: true)).to eq(1.0)
    end

    it "returns zero for sections without details unless directly covered" do
      section = create(:content, :section)

      expect(helper.section_coverage_fraction(section, {})).to eq(0.0)
    end
  end

  describe "#level_coverage_fraction" do
    it "counts a fully covered section as one and a partial section as half" do
      level = create(:content, :level)
      full = create(:content, :section, parent: level)
      full_details = create_list(:content, 2, :detail, parent: full)
      partial = create(:content, :section, parent: level)
      partial_details = create_list(:content, 3, :detail, parent: partial)
      coverages = {
        full_details.first.id => instance_double(UnitCoverage),
        full_details.second.id => instance_double(UnitCoverage),
        partial_details.first.id => instance_double(UnitCoverage)
      }

      expect(helper.level_coverage_fraction(level, coverages)).to be_within(0.001).of(0.75)
    end

    it "returns complete for direct level coverage" do
      level = create(:content, :level)
      section = create(:content, :section, parent: level)
      create(:content, :detail, parent: section)

      expect(helper.level_coverage_fraction(level, { level.id => instance_double(UnitCoverage) })).to eq(1.0)
    end

    it "returns zero for levels without sections unless directly covered" do
      level = create(:content, :level)

      expect(helper.level_coverage_fraction(level, {})).to eq(0.0)
    end
  end

  describe "#coverage_row_button" do
    it "renders a disabled Remove button with a tooltip when covered via an ancestor" do
      section = create(:content, :section)

      html = helper.coverage_row_button(build(:unit), section, {}, ancestor_covered: true, via_title: "Topic Area 1")

      aggregate_failures do
        expect(html).to include(I18n.t("helpers.coverage.remove"))
        expect(html).to include("disabled")
        expect(html).to include(I18n.t("units.show.covered_via", title: "Topic Area 1"))
      end
    end

    it "renders the toggle button when there is no ancestor coverage" do
      detail = create(:content, :detail)
      unit = create(:unit)

      html = helper.coverage_row_button(unit, detail, {})

      expect(html).to include(I18n.t("helpers.coverage.add"))
    end
  end

  describe "#detail_covered?" do
    it "returns true for direct, section, and level coverage" do
      level = create(:content, :level)
      section = create(:content, :section, parent: level)
      detail = create(:content, :detail, parent: section)

      aggregate_failures do
        expect(helper.detail_covered?(detail, { detail.id => instance_double(UnitCoverage) })).to be(true)
        expect(helper.detail_covered?(detail, { section.id => instance_double(UnitCoverage) }, ancestor_covered: true)).to be(true)
        expect(helper.detail_covered?(detail, {}, ancestor_covered: true)).to be(true)
        expect(helper.detail_covered?(detail, {})).to be(false)
      end
    end
  end

  describe "#unit_detail_coverage_count" do
    it "counts directly linked details" do
      unit = create(:unit)
      detail = create(:content, :detail)
      create(:unit_coverage, unit: unit, content: detail)

      coverages = { unit.id => unit.unit_coverages.to_a }
      expect(helper.unit_detail_coverage_count(unit, coverages, { detail.id => [ detail.id ] })).to eq(1)
    end

    it "expands section and level links without double counting" do
      level = create(:content, :level)
      section = create(:content, :section, parent: level)
      details = create_list(:content, 2, :detail, parent: section)
      other_detail = create(:content, :detail)
      unit = create(:unit)
      create(:unit_coverage, unit: unit, content: level)
      create(:unit_coverage, unit: unit, content: details.first)
      create(:unit_coverage, unit: unit, content: other_detail)
      map = {
        level.id => details.map(&:id),
        section.id => details.map(&:id),
        details.first.id => [ details.first.id ],
        details.second.id => [ details.second.id ],
        other_detail.id => [ other_detail.id ]
      }

      coverages = { unit.id => unit.unit_coverages.to_a }
      expect(helper.unit_detail_coverage_count(unit, coverages, map)).to eq(3)
    end

    it "returns zero without coverages" do
      unit = create(:unit)

      expect(helper.unit_detail_coverage_count(unit, {}, {})).to eq(0)
    end
  end

  describe "#user_topic_progress" do
    it "returns a pure detail ratio without partial weighting" do
      section = create(:content, :section)
      details = create_list(:content, 3, :detail, parent: section)

      expect(helper.user_topic_progress(section, Set[details.first.id])).to eq([ 1, 3 ])
    end

    it "counts direct topic coverage as complete" do
      section = create(:content, :section)
      create_list(:content, 2, :detail, parent: section)

      expect(helper.user_topic_progress(section, Set[section.id])).to eq([ 2, 2 ])
    end

    it "treats a topic without details as a binary check-off via direct coverage" do
      section = create(:content, :section)

      aggregate_failures do
        expect(helper.user_topic_progress(section, Set[section.id])).to eq([ 1, 1 ])
        expect(helper.user_topic_progress(section, Set.new)).to eq([ 0, 1 ])
      end
    end

    it "ignores ancestor coverage for topics without details" do
      section = create(:content, :section)

      expect(helper.user_topic_progress(section, Set.new, ancestor_covered: true)).to eq([ 0, 1 ])
    end
  end

  describe "#user_topic_area_progress" do
    it "sums covered details across topics without modification" do
      level = create(:content, :level)
      full = create(:content, :section, parent: level)
      create_list(:content, 2, :detail, parent: full)
      partial = create(:content, :section, parent: level)
      partial_details = create_list(:content, 3, :detail, parent: partial)
      covered = Set[full.children.first.id, full.children.second.id, partial_details.first.id]

      expect(helper.user_topic_area_progress(level, covered)).to eq([ 3, 5 ])
    end

    it "counts direct topic-area coverage as complete" do
      level = create(:content, :level)
      section = create(:content, :section, parent: level)
      create_list(:content, 2, :detail, parent: section)

      expect(helper.user_topic_area_progress(level, Set[level.id])).to eq([ 2, 2 ])
    end

    it "counts topics without details as binary items in mixed topic areas" do
      level = create(:content, :level)
      with_details = create(:content, :section, parent: level)
      detail = create(:content, :detail, parent: with_details)
      bare = create(:content, :section, parent: level)

      aggregate_failures do
        expect(helper.user_topic_area_progress(level, Set[detail.id, bare.id])).to eq([ 2, 2 ])
        expect(helper.user_topic_area_progress(level, Set[detail.id])).to eq([ 1, 2 ])
      end
    end

    it "counts a topic area of only bare topics as covered topics over total topics" do
      level = create(:content, :level)
      first = create(:content, :section, parent: level)
      second = create(:content, :section, parent: level)

      aggregate_failures do
        expect(helper.user_topic_area_progress(level, Set.new)).to eq([ 0, 2 ])
        expect(helper.user_topic_area_progress(level, Set[first.id])).to eq([ 1, 2 ])
        expect(helper.user_topic_area_progress(level, Set[first.id, second.id])).to eq([ 2, 2 ])
      end
    end

    it "ignores direct level coverage for topic areas with only bare topics" do
      level = create(:content, :level)
      create(:content, :section, parent: level)
      create(:content, :section, parent: level)

      expect(helper.user_topic_area_progress(level, Set[level.id])).to eq([ 0, 2 ])
    end
  end

  describe "#training_hours_percent" do
    it "caps at 100 percent" do
      aggregate_failures do
        expect(helper.training_hours_percent(25)).to eq(50)
        expect(helper.training_hours_percent(75)).to eq(100)
        expect(helper.user_progress_percent(1, 3)).to eq(33)
        expect(helper.user_progress_percent(0, 0)).to eq(0)
      end
    end
  end

  describe "#coverage_progress_badge" do
    it "renders a partial fill with a translated tooltip" do
      section = create(:content, :section)

      html = helper.coverage_progress_badge(section, 1.0 / 3)

      aggregate_failures do
        expect(html).to include("linear-gradient")
        expect(html).to include("33%")
        expect(html).to include(I18n.t("units.show.coverage_progress", percent: 33))
        expect(html).to include(I18n.t("activerecord.enums.content.content_type.section"))
      end
    end

    it "renders a plain badge when coverage is empty" do
      level = create(:content, :level)

      expect(helper.coverage_progress_badge(level, 0.0)).not_to include("linear-gradient")
    end

    it "renders a full fill with a translated tooltip when complete" do
      section = create(:content, :section)

      html = helper.coverage_progress_badge(section, 1.0)

      aggregate_failures do
        expect(html).to include("linear-gradient")
        expect(html).to include("100%")
        expect(html).to include(I18n.t("units.show.coverage_progress", percent: 100))
      end
    end

    it "renders a binary full fill for a covered detail and plain when uncovered" do
      detail = create(:content, :detail)

      covered = helper.coverage_progress_badge(detail, 1.0)

      aggregate_failures do
        expect(covered).to include("linear-gradient")
        expect(covered).to include(I18n.t("units.show.coverage_progress", percent: 100))
        expect(helper.coverage_progress_badge(detail, 0.0)).not_to include("linear-gradient")
      end
    end
  end
end
