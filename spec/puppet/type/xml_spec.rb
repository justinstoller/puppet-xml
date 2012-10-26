require 'spec_helper'

describe Puppet::Type.type(:xml) do
  let(:name) { 'blah' }
  let(:catalog) { Puppet::Resource::Catalog.new }
  let(:xml) { described_class.new(:name => name, :catalog => catalog) }

  it 'defaults to an empty Hash' do
    expect( xml[:attributes] ).to be == Hash.new
  end

  it 'accepts a String or Hash as an argument' do
    xml[:attributes] = 'key=value'
    expect( xml[:attributes] ).to be == {'key' => 'value'}
    xml[:attributes] = {'key' => 'value'}
    expect( xml[:attributes] ).to be == {'key' => 'value'}
  end

  it 'raises an error on non String or Hash input' do
    expect { xml[:attributes] = 1 }.to raise_error(Puppet::Error)
  end
end
