require 'rails_helper'

RSpec.describe SiteSetting, type: :model do
  describe '.get' do
    it 'returns the default for a setting nobody has changed' do
      expect(described_class.get('signups_enabled')).to be(true)
      expect(described_class.get('maintenance_mode')).to be(false)
      expect(described_class.get('homepage_streams_limit')).to eq(5)
      expect(described_class.get('announcement_level')).to eq('info')
    end

    it 'accepts a symbol as well as a string' do
      expect(described_class.get(:signups_enabled)).to be(true)
    end

    it 'raises for a setting that does not exist, rather than silently returning nil' do
      expect { described_class.get('nope') }.to raise_error(ArgumentError, /unknown setting/)
    end

    it 'returns stored values with the right type' do
      described_class.update_values('signups_enabled' => '0', 'homepage_streams_limit' => '3', 'announcement_message' => 'Hello')

      expect(described_class.get('signups_enabled')).to be(false)
      expect(described_class.get('homepage_streams_limit')).to eq(3)
      expect(described_class.get('announcement_message')).to eq('Hello')
    end

    it 'falls back to the default when a stored value has been corrupted' do
      described_class.create!(key: 'homepage_streams_limit', value: 'lots')
      expect(described_class.get('homepage_streams_limit')).to eq(5)
    end

    it 'has a default that is itself valid, for every setting' do
      described_class::DEFINITIONS.each_value do |definition|
        result = described_class.update_values(definition.key => definition.default.to_s)
        expect(result).to be_success, "default for #{definition.key} is not accepted: #{result.errors}"
      end
    end
  end

  describe '.values' do
    it 'returns every setting, typed' do
      expect(described_class.values.keys).to match_array(described_class::DEFINITIONS.keys)
    end
  end

  describe '.update_values' do
    it 'reports what changed, old and new, and ignores values that are the same' do
      result = described_class.update_values('signups_enabled' => 'false', 'maintenance_mode' => 'false')

      expect(result).to be_success
      expect(result.changes).to eq('signups_enabled' => [true, false])
    end

    it 'saves nothing at all if any one value is invalid' do
      result = described_class.update_values('signups_enabled' => 'false', 'homepage_streams_limit' => '99')

      expect(result).not_to be_success
      expect(result.errors.keys).to eq(['homepage_streams_limit'])
      expect(described_class.get('signups_enabled')).to be(true)
      expect(described_class.count).to eq(0)
    end

    it 'validates whole numbers within the range' do
      ['0', '11', 'five', '', '2.5', '1e1'].each do |bad|
        result = described_class.update_values('homepage_streams_limit' => bad)
        expect(result.errors).to have_key('homepage_streams_limit'), "#{bad.inspect} should be refused"
      end
      %w[1 10 7].each do |good|
        expect(described_class.update_values('homepage_streams_limit' => good)).to be_success
      end
    end

    it 'validates choices' do
      expect(described_class.update_values('announcement_level' => 'purple').errors).to have_key('announcement_level')
      expect(described_class.update_values('announcement_level' => 'warning')).to be_success
    end

    it 'limits the length of text' do
      expect(described_class.update_values('announcement_message' => 'x' * 301).errors).to have_key('announcement_message')
      expect(described_class.update_values('announcement_message' => 'x' * 300)).to be_success
    end

    it 'trims text' do
      described_class.update_values('announcement_message' => '  Hi there  ')
      expect(described_class.get('announcement_message')).to eq('Hi there')
    end

    it 'ignores keys that are not settings' do
      expect(described_class.update_values('admin' => 'true', 'signups_enabled' => '0')).to be_success
      expect(described_class.count).to eq(1)
    end

    it 'updates an existing row instead of adding another' do
      described_class.update_values('homepage_streams_limit' => '2')
      described_class.update_values('homepage_streams_limit' => '4')
      expect(described_class.where(key: 'homepage_streams_limit').count).to eq(1)
      expect(described_class.get('homepage_streams_limit')).to eq(4)
    end
  end

  describe 'caching' do
    around do |example|
      original = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      example.run
    ensure
      Rails.cache = original
    end

    it 'reads from the cache, and sees a change straight away' do
      described_class.update_values('signups_enabled' => 'false')
      expect(described_class.get('signups_enabled')).to be(false)

      expect(described_class).not_to receive(:pluck)
      3.times { described_class.get('signups_enabled') }
    end

    it 'is cleared when a setting is saved, so every process sees the new value' do
      expect(described_class.get('maintenance_mode')).to be(false)
      described_class.update_values('maintenance_mode' => 'true')
      expect(described_class.get('maintenance_mode')).to be(true)
    end
  end

  describe 'validations' do
    it 'only allows keys that are defined' do
      expect(described_class.new(key: 'secret_backdoor', value: 'x')).not_to be_valid
    end
  end
end
