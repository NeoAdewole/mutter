require 'rails_helper'

RSpec.describe SitePages do
  describe '.ensure!' do
    it 'creates Home, About and the four landing pages, all published' do
      expect { described_class.ensure! }.to change(Page, :count).by(6)

      expect(Page.site_pages.pluck(:system_key)).to match_array(%w[home about streaming content gaming community])
      expect(Page.site_pages).to all(be_published)
      expect(Page.site_pages.pluck(:section).compact).to be_empty
    end

    it 'is safe to run again and never overwrites an edit' do
      described_class.ensure!
      Page.find_by!(system_key: 'about').update!(title: 'Who we are', body: 'Changed')
      Page.find_by!(system_key: 'home').blocks.destroy_all

      expect { described_class.ensure! }.not_to change(Page, :count)
      expect(Page.find_by!(system_key: 'about')).to have_attributes(title: 'Who we are', body: 'Changed')
      expect(Page.find_by!(system_key: 'home').blocks).to be_empty
    end

    it 'fills in only the pages that are missing' do
      described_class.ensure!
      Page.find_by!(system_key: 'gaming').destroy!

      expect { described_class.ensure! }.to change(Page, :count).by(1)
    end
  end

  describe '.page' do
    it 'finds a site page, creating the set on first use' do
      expect(Page.site_pages).to be_none

      expect(described_class.page('about')).to have_attributes(system_key: 'about', title: 'About Us')
      expect(Page.site_pages.count).to eq(6)
    end

    it 'raises for a key that is not a site page' do
      expect { described_class.page('nope') }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '.all' do
    it 'lists Home, About, then the sections in menu order' do
      expect(described_class.all.map(&:system_key)).to eq(%w[home about streaming content gaming community])
    end
  end

  describe 'default content' do
    let(:home) { described_class.page('home') }

    it 'gives each landing page its section title and blurb' do
      Section.all.each do |section|
        expect(described_class.page(section.key)).to have_attributes(title: section.title, body: section.blurb, show_title: true)
      end
    end

    it 'keeps the About text' do
      about = described_class.page('about')

      expect(about.rendered_body).to include('The Idea').and include('collective voice')
    end

    it 'makes Home what the site showed before: a carousel, four cards for the sections, then the intro' do
      expect(home.show_title).to be false
      expect(home.blocks.map(&:kind)).to eq(%w[carousel cards text])

      carousel, cards, text = home.blocks.to_a
      expect(carousel.show_live_streams).to be true
      expect(carousel.items.map(&:alt_text)).to eq(['Banner 1', 'Banner 2', 'Banner 3', 'Banner 4'])
      expect(cards.columns).to eq(4)
      expect(cards.items.map { |card| card.featured_page.system_key }).to eq(Section.keys)
      expect(cards.items.map(&:button_label)).to eq(Section.all.map { |section| "Explore #{section.title}" })
      expect(text.body).to include('We are building a digital community').and include('- Empowers creators')
    end
  end

  describe 'the Page model for site pages' do
    let(:about) { described_class.page('about') }

    it 'has no section, a fixed address and is always published' do
      home = described_class.page('home')

      expect(about).to have_attributes(section: nil, slug: 'about', published: true)
      expect([home.public_path, about.public_path, described_class.page('gaming').public_path]).to eq(['/', '/about', '/gaming'])
      expect(about.publicly_visible?).to be true
      about.update!(published: false)
      expect(about.reload).to be_published
    end

    it 'is named in the audit log as a site page' do
      expect(about.audit_label).to eq('Site page: About Us')
    end

    it 'must not claim a section, and every other page must have one' do
      expect(build(:page, section: 'content', system_key: 'about')).not_to be_valid
      expect(build(:page, section: nil)).not_to be_valid
      expect(build(:page, section: nil, system_key: 'elsewhere')).not_to be_valid
    end

    it 'is unique by key' do
      about
      expect(build(:page, section: nil, system_key: 'about', title: 'Another')).not_to be_valid
    end

    it 'is kept out of the menus and the section lists' do
      described_class.ensure!
      create(:page, :published, section: 'content', title: 'Guides')

      expect(Page.navigation.fetch('content').map { |node| node.page.title }).to eq(['Guides'])
      expect(Page.navigation.values.flatten.size).to eq(1)
      expect(Page.rows_for('content').map { |row| row.page.title }).to eq(['Guides'])
    end

    it 'is refused by the database when it has neither a section nor a key' do
      expect { Page.new(title: 'Lost', slug: 'lost').save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end
end
