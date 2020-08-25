require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::LndNodeInfoAgent do
  before(:each) do
    @valid_options = Agents::LndNodeInfoAgent.new.default_options
    @checker = Agents::LndNodeInfoAgent.new(:name => "LndNodeInfoAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
