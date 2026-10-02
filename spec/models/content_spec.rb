require "rails_helper"

RSpec.describe Content do
  describe "validations" do
    it "requires title, content_type and position" do
      expect(build(:content, :level)).to be_valid
      expect(build(:content, :level, title: nil)).not_to be_valid
      expect(build(:content, :level, position: nil)).not_to be_valid
    end

    it "requires content_type" do
      content = build(:content, :level)
      content.content_type = nil
      expect(content).not_to be_valid
    end

    it "requires non-negative integer position" do
      expect(build(:content, :level, position: -1)).not_to be_valid
    end

    it "orders children by position" do
      level = create(:content, :level)
      second = create(:content, :section, parent: level, position: 1, title: "B")
      first = create(:content, :section, parent: level, position: 0, title: "A")

      expect(level.children.to_a).to eq([ first, second ])
    end
  end

  describe "hierarchy" do
    it "allows a level without a parent" do
      expect(build(:content, :level, parent: nil)).to be_valid
    end

    it "prevents a level from having a parent" do
      parent = create(:content, :level)

      expect(build(:content, :level, parent: parent)).not_to be_valid
    end

    it "requires a section to have a level parent" do
      expect(build(:content, :section, parent: nil)).not_to be_valid
      expect(build(:content, content_type: :section, parent: create(:content, :level))).to be_valid
    end

    it "rejects a section under another section" do
      section_parent = create(:content, :section)

      expect(build(:content, content_type: :section, parent: section_parent)).not_to be_valid
    end

    it "rejects a section under a detail" do
      detail = create(:content, :detail)

      expect(build(:content, content_type: :section, parent: detail)).not_to be_valid
    end

    it "requires a detail to have a section parent" do
      expect(build(:content, :detail, parent: nil)).not_to be_valid
      expect(build(:content, content_type: :detail, parent: create(:content, :section))).to be_valid
    end

    it "rejects a detail directly under a level" do
      level = create(:content, :level)

      expect(build(:content, content_type: :detail, parent: level)).not_to be_valid
    end

    it "rejects a detail under another detail" do
      detail_parent = create(:content, :detail)

      expect(build(:content, content_type: :detail, parent: detail_parent)).not_to be_valid
    end

    it "prevents a level from directly containing details" do
      level = create(:content, :level)
      detail = build(:content, content_type: :detail, parent: level)

      expect(detail).not_to be_valid
      expect(detail.errors[:parent]).to be_present
    end

    it "prevents a section from containing sections" do
      section = create(:content, :section)
      nested = build(:content, content_type: :section, parent: section)

      expect(nested).not_to be_valid
    end

    it "prevents a section from containing levels" do
      section = create(:content, :section)
      level = build(:content, content_type: :level, parent: section)

      expect(level).not_to be_valid
    end

    it "prevents a detail from having children" do
      detail = create(:content, :detail)
      child = build(:content, content_type: :detail, parent: detail)

      expect(child).not_to be_valid
      expect(detail.tap { |d| d.children.reload }).to be_valid
      detail.children << build(:content, content_type: :detail, parent: detail, title: "Nested")
      expect(detail).not_to be_valid
    end

    it "never exceeds three levels" do
      level = create(:content, :level)
      section = create(:content, :section, parent: level)
      detail = create(:content, :detail, parent: section)

      fourth = build(:content, content_type: :detail, parent: detail)
      expect(fourth).not_to be_valid
    end

    it "restricts destroying parents with children" do
      level = create(:content, :level)
      create(:content, :section, parent: level)

      result = Content.find(level.id).destroy

      aggregate_failures do
        expect(result).to be(false)
        expect(Content.exists?(level.id)).to be(true)
      end
    end
  end
end
