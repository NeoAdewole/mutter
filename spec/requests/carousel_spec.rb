require 'rails_helper'

RSpec.describe 'Home page carousel', type: :request do
  let(:carousel) do
    get root_path
    Nokogiri::HTML(response.body).at_css('[data-controller="carousel"]')
  end

  it 'renders the shared carousel wired to its Stimulus controller' do
    expect(carousel).to be_present
    expect(carousel.css('[data-carousel-target="track"]').size).to eq(1)
    expect(carousel.css('[data-carousel-target="slide"]').size).to eq(4)
    expect(carousel.css('[data-carousel-target="indicator"]').size).to eq(4)
  end

  it 'navigates with buttons wired to controller actions, not hash-anchor links' do
    expect(carousel.css('button[data-action="carousel#previous"]').size).to eq(1)
    expect(carousel.css('button[data-action="carousel#next"]').size).to eq(1)
    expect(carousel.css('a[href^="#slide"]')).to be_empty
  end

  it 'is exposed to assistive tech as a carousel, starting on the first slide' do
    expect(carousel['aria-roledescription']).to eq('carousel')
    expect(carousel.css('[role="group"][aria-roledescription="slide"]').size).to eq(4)
    current = carousel.css('[data-carousel-target="indicator"][aria-current="true"]')
    expect(current.size).to eq(1)
    expect(current.first.text.strip).to eq('1')
  end

  it 'is styled with plain Tailwind utilities only (no DaisyUI/Bootstrap component classes)' do
    classes = ([carousel] + carousel.css('*')).flat_map { |node| node['class'].to_s.split }
    component_classes = %w[carousel carousel-item btn btn-circle btn-xs rounded-box]

    expect(classes & component_classes).to be_empty
  end
end
