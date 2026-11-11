require 'rails_helper'

RSpec.describe 'Live streams in the home page carousel', type: :request do
  let(:live) do
    [
      Twitch::Stream.new(login: 'alice', name: 'Alice', title: 'Speedrunning night', game: 'Celeste', viewers: 1234),
      Twitch::Stream.new(login: 'bob', name: 'Bob', title: 'Cozy art stream', game: 'Art', viewers: 56)
    ]
  end

  let(:carousel) { Nokogiri::HTML(response.body).at_css('[data-controller="carousel"]') }

  describe 'when users are streaming' do
    before do
      allow(Twitch::LiveStreams).to receive(:current).and_return(live)
      get root_path
    end

    it 'puts a slide for each live stream ahead of the regular banners' do
      slides = carousel.css('[data-carousel-target="slide"]')

      expect(slides.size).to eq(2 + 4)
      expect(slides[0].text).to include('Alice')
      expect(slides[1].text).to include('Bob')
      expect(slides[0].css('iframe').size).to eq(1)
      expect(slides.last.css('img').size).to eq(1)
      expect(slides.last.css('iframe')).to be_empty
    end

    it "embeds each channel's Twitch player for this site, muted, without loading it until the slide is shown" do
      frame = carousel.css('iframe[data-carousel-target="frame"]').first

      expect(frame['src']).to be_nil
      uri = URI(frame['data-src'])
      expect(uri.host).to eq('player.twitch.tv')
      expect(Rack::Utils.parse_query(uri.query)).to include('channel' => 'alice', 'parent' => 'www.example.com', 'muted' => 'true')
      expect(frame['title']).to eq('Alice live on Twitch')
      expect(frame['allow']).to include('autoplay')
    end

    it 'says who is live, what they are playing, how many are watching, and links out to the channel' do
      slide = carousel.css('[data-carousel-target="slide"]').first

      expect(slide.text).to include('Live').and include('Speedrunning night').and include('Celeste').and include('1,234')
      link = slide.at_css('a[href="https://www.twitch.tv/alice"]')
      expect(link).to be_present
      expect(link['rel']).to include('noopener')
      expect(link['target']).to eq('_blank')
    end

    it 'adds an indicator per slide, flagging the live ones, starting on the first' do
      indicators = carousel.css('[data-carousel-target="indicator"]')

      expect(indicators.size).to eq(6)
      expect(indicators.first['aria-label']).to eq('Go to slide 1 (Alice, live)')
      expect(indicators.last['aria-label']).to eq('Go to slide 6')
      expect(indicators.first['aria-current']).to eq('true')
      expect(indicators.count { |indicator| indicator['aria-current'] == 'true' }).to eq(1)
    end

    it 'still uses only plain Tailwind utilities' do
      classes = ([carousel] + carousel.css('*')).flat_map { |node| node['class'].to_s.split }

      expect(classes & %w[carousel carousel-item btn btn-circle btn-xs rounded-box badge]).to be_empty
    end
  end

  describe 'when nobody is streaming' do
    it 'shows just the regular banners, with no players' do
      allow(Twitch::LiveStreams).to receive(:current).and_return([])
      get root_path

      expect(carousel.css('[data-carousel-target="slide"]').size).to eq(4)
      expect(carousel.css('iframe')).to be_empty
    end
  end
end
