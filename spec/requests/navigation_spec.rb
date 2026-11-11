require 'rails_helper'

RSpec.describe 'Site navigation', type: :request do
  let(:desktop) { html.at_css('#main-nav') }
  let(:drawer) { html.at_css('.drawer-side') }

  def desktop_item(label)
    desktop.css('.navbar-center > ul > li').find { |li| li.at_xpath('./a')&.text&.strip == label }
  end

  def drawer_item(label)
    drawer.css('ul.menu > li').find { |li| li.at_xpath('./a')&.text&.strip == label }
  end

  describe 'the four sections' do
    before { get root_path }

    it 'are all in the desktop navbar, linking to their landing pages' do
      Section.all.each do |section|
        item = desktop_item(section.title)
        expect(item).to be_present, "#{section.title} missing from desktop navbar"
        expect(item.at_xpath('./a')['href']).to eq(section.path)
      end
    end

    it 'are all in the mobile drawer, linking to their landing pages' do
      Section.all.each do |section|
        item = drawer_item(section.title)
        expect(item).to be_present, "#{section.title} missing from the drawer"
        expect(item.at_xpath('./a')['href']).to eq(section.path)
      end
    end

    it 'appear in order after Home and About' do
      labels = desktop.css('.navbar-center > ul > li > a').map { |a| a.text.strip }
      expect(labels.first(6)).to eq(%w[Home About Streaming Content Gaming Community])
    end
  end

  describe 'sub pages' do
    let!(:guides) { create(:page, :published, section: 'content', title: 'Guides', slug: 'guides') }
    let!(:beginner) { create(:page, :published, section: 'content', parent: guides, title: 'Beginner', slug: 'beginner') }

    before do
      create(:page, :draft, section: 'content', title: 'Hidden draft')
      create(:page, :draft, section: 'content', parent: guides, title: 'Hidden sub draft')
      get root_path
    end

    it 'list published pages and their sub pages in the desktop dropdown' do
      menu = desktop_item('Content').at_css('ul')
      expect(menu['aria-label']).to eq('Content pages')
      expect(menu.at_css("a[href='/content/guides']").text.strip).to eq('Guides')
      expect(menu.at_css("li li a[href='/content/guides/beginner']").text.strip).to eq('Beginner')
    end

    it 'are nested beneath their section in the mobile drawer' do
      menu = drawer_item('Content').at_css('ul')
      expect(menu.at_css("a[href='/content/guides']")).to be_present
      expect(menu.at_css("li li a[href='/content/guides/beginner']")).to be_present
    end

    it 'never include drafts' do
      expect(response.body).not_to include('Hidden draft')
      expect(response.body).not_to include('Hidden sub draft')
    end

    it 'marks the current page for assistive technology' do
      get '/content/guides'
      current = desktop.css("[aria-current='page']").map { |a| a['href'] }
      expect(current).to include('/content/guides')
    end

    it 'leave sections without any pages as a plain link rather than an empty dropdown' do
      expect(desktop_item('Gaming').at_css('ul')).to be_nil
      expect(drawer_item('Gaming').at_css('ul')).to be_nil
    end
  end

  describe 'Live chat' do
    it 'is under Streaming in both menus, replacing the old top-level Streaming link' do
      get root_path
      expect(desktop_item('Streaming').at_css("ul a[href='/streaming/live-chat']").text.strip).to eq('Live chat')
      expect(drawer_item('Streaming').at_css("ul a[href='/streaming/live-chat']")).to be_present
      expect(desktop.css(".navbar-center > ul > li > a[href='/streaming/live-chat']")).to be_empty
    end

    it 'comes before any published Streaming pages' do
      create(:page, :published, section: 'streaming', title: 'Setup')
      get root_path
      labels = desktop_item('Streaming').css('ul > li > a').map { |a| a.text.strip }
      expect(labels).to eq(['Live chat', 'Setup'])
    end
  end

  describe 'the Admin entry' do
    it 'is absent for guests' do
      get root_path
      expect(html.css("a[href^='/admin']")).to be_empty
    end

    it 'is absent for regular users' do
      sign_in_as(create(:user))
      get root_path
      expect(html.css("a[href^='/admin']")).to be_empty
    end

    it 'is present for admins in both the navbar and the drawer' do
      sign_in_as(create(:user, :admin))
      get root_path
      expect(desktop.css("a[href='/admin']").map { |a| a.text.strip }).to include('Admin')
      expect(drawer.css("a[href='/admin']").map { |a| a.text.strip }).to include('Admin')
    end
  end

  describe 'Twitter Accounts and Tweets (built-in sub pages of Community)' do
    before { get root_path }

    it 'are in the Community dropdown and drawer, and no longer top-level' do
      menu = desktop_item('Community').at_css('ul')
      expect(menu.css('a').map { |a| [a.text.strip, a['href']] }).to eq(
        [['Twitter Accounts', twitter_accounts_path], %w[Tweets /tweets]]
      )
      expect(drawer_item('Community').css("ul a[href='#{tweets_path}']")).not_to be_empty
      expect(desktop.css(".navbar-center > ul > li > a[href='#{tweets_path}']")).to be_empty
    end

    it 'come before any published Community pages' do
      create(:page, :published, section: 'community', title: 'Rules')
      get root_path
      labels = desktop_item('Community').css('ul > li > a').map { |a| a.text.strip }
      expect(labels).to eq(['Twitter Accounts', 'Tweets', 'Rules'])
    end

    it 'are also listed on the Community landing page' do
      get '/community'
      expect(html.css("[data-section-pages] a[href='#{twitter_accounts_path}']")).not_to be_empty
      expect(html.css("[data-section-pages] a[href='#{tweets_path}']")).not_to be_empty
    end
  end

  describe 'accessibility' do
    before { get root_path }

    it 'labels the navigation landmark and each dropdown list' do
      create(:page, :published, section: 'gaming')
      get root_path
      expect(desktop['aria-label']).to eq('Main')
      expect(desktop.css('.navbar-center ul ul').map { |ul| ul['aria-label'] }).to all(be_present)
    end

    it 'keeps the mobile drawer toggle labelled' do
      expect(html.at_css("label[for='nav-drawer'][aria-label='Open menu']")).to be_present
    end
  end

  describe 'home page cards' do
    it 'link to each section' do
      get root_path
      Section.all.each do |section|
        link = html.at_css("#offers a[href='#{section.path}']")
        expect(link).to be_present, "no home card link to #{section.path}"
        expect(link['aria-label'] || link.text).to include(section.title)
      end
    end

    it 'no longer show the placeholder "Buy Now" buttons' do
      get root_path
      expect(response.body).not_to include('Buy Now')
    end
  end
end
