require 'rails_helper'

RSpec.describe Section do
  it 'defines the four top-level sections, in navbar order' do
    expect(described_class.all.map(&:key)).to eq(%w[streaming content gaming community])
  end

  it 'gives each section a title and a blurb' do
    described_class.all.each do |section|
      expect(section.title).to be_present
      expect(section.blurb).to be_present
    end
  end

  describe '.find' do
    it 'finds a section by key' do
      expect(described_class.find('gaming').title).to eq('Gaming')
    end

    it 'returns nil for an unknown key' do
      expect(described_class.find('nope')).to be_nil
    end
  end

  it 'knows its landing page path' do
    expect(described_class.find('content').path).to eq('/content')
  end
end
