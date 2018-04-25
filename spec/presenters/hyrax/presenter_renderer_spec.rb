RSpec.describe Hyrax::PresenterRenderer do
  let(:work) { GenericWork.new }
  let(:ability) { double }
  let(:document) { SolrDocument.new(work.to_solr) }
  let(:presenter) { Hyrax::WorkShowPresenter.new(document, ability) }
  let(:view_context) { ActionView::TestCase::TestController.new.view_context }
  let(:renderer) { described_class.new(presenter, view_context) }

  describe "#label" do
    it "calls translate with defaults" do
      expect(renderer).to receive(:t).with(:"generic_work.date_created",
                                           default: [:"defaults.date_created", "Date created"],
                                           scope: :"simple_form.labels")
      renderer.label(:date_created)
    end

    context "of a field with a translation" do
      subject { renderer.label(:date_created) }

      it { is_expected.to eq 'Date Created' }
    end

    context "of a field without a translation" do
      subject { renderer.label(:date_uploaded) }

      it { is_expected.to eq 'Date uploaded' }
    end
  end
end
