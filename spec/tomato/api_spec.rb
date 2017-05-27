require "spec_helper"

RSpec.describe Tomato::Api do
  it "has a version number" do
    expect(Tomato::Api::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
