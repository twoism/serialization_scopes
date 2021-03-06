require File.expand_path(File.dirname(__FILE__) + '/helper')

describe SerializationScopes do

  before do
    ActiveRecord::Base.stub!(:establish_connection)
  end

  class SomeModel < ActiveRecord::Base
    serialization_scope :default, :only => [:id, :name], :methods => :currency
    serialization_scope :admin, :only => [:id, :secret]
    serialization_scope :excepted, :except => [:secret]
    serialization_scope :wow_root, :root => 'wow-root'
    after_initialize    :set_defaults

    def self.columns
      @columns ||= [
        ActiveRecord::ConnectionAdapters::Column.new('id', nil, 'integer'),
        ActiveRecord::ConnectionAdapters::Column.new('name', nil, 'string'),
        ActiveRecord::ConnectionAdapters::Column.new('secret', nil, 'string')
      ]
    end

    def set_defaults
      self.id     = 1
      self.name   = 'Any'
      self.secret = 'key'
    end

    def currency
      'USD'
    end
  end

  it 'should constraint to_xml' do
    SomeModel.new.to_xml.should == %(<?xml version="1.0" encoding="UTF-8"?>
<some-model>
  <name>Any</name>
  <id type="integer">1</id>
  <currency>USD</currency>
</some-model>
)
  end

  def as_hash(options = {})
    ActiveSupport::JSON.decode(SomeModel.new.to_json(options))
  end

  it 'should constraint to_json' do
    as_hash.should == { "name" => "Any", "currency" => "USD", "id" => 1 }
  end

  it 'should allow further restrictions' do
    as_hash(:only => :name).should == { "name" => "Any", "currency" => "USD" }
    as_hash(:methods => []).should == { "name" => "Any", "id" => 1 }
  end

  it 'should deny extensions if (default) scope is selected' do
    as_hash(:only => [:id, :secret]).should == { "id" => 1, "currency" => "USD" }
  end

  it 'should have separate behaviours for different scopes' do
    as_hash(:scope => :admin).should == { "id" => 1, "secret" => "key" }
  end

  it 'should fallback to default scope if invalid scope is given' do
    as_hash(:scope => :invalid).should == { "name" => "Any", "currency" => "USD", "id" => 1 }
  end

  def options_for(custom_options)
    SomeModel.send(:scoped_serialization_options, custom_options)
  end

  it 'should not relax the specified column list (when list is set by :only option)' do
    options_for(:scope => :default, :only => [:id, :secret])[:only].should == [:id]
    options_for(:scope => :default, :only => :secret)[:only].should == []
    options_for(:scope => :default, :methods => [:some_method, :currency])[:methods].should == [:currency]
  end

  it 'should restrict the specified column list (when list is set by :except option)' do
    options_for(:scope => :excepted, :except => :id)[:except].should == [:id, :secret]
  end

  it "should pass through options it doesn't know about" do
    SomeModel.new.to_xml(:root => "wow-root").should include('<wow-root>')
    SomeModel.new.to_xml(:scope => :wow_root).should include('<wow-root>')
  end


end