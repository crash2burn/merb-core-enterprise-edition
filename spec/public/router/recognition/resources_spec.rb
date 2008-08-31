require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe "When recognizing requests," do

  describe "a basic resource route" do
  
    before :each do
      Merb::Router.prepare do
        resources :blogposts
      end
    end
  
    it "should have an index action with an optional :format" do
      route_to('/blogposts').should           have_route(:controller => 'blogposts', :action => 'index', :id => nil, :format => nil)
      route_to('/blogposts/index').should     have_route(:controller => 'blogposts', :action => 'index', :id => nil, :format => nil)
      route_to('/blogposts.js').should        have_route(:controller => 'blogposts', :action => 'index', :id => nil, :format => "js")
      route_to('/blogposts/index.xml').should have_route(:controller => 'blogposts', :action => 'index', :id => nil, :format => "xml")
    end
  
    it "should have a create action with an optional :format" do
      route_to('/blogposts',    :method => :post).should have_route(:controller => 'blogposts', :action => 'create', :id => nil, :format => nil)
      route_to('/blogposts.js', :method => :post).should have_route(:controller => 'blogposts', :action => 'create', :id => nil, :format => "js")
    end

    it "should not match put or delete on the collection" do
      [:put, :delete].each do |method|
        route_to('/blogposts',    :method => method).should have_nil_route
        route_to('/blogposts.js', :method => method).should have_nil_route
      end
    end
  
    it "should have a new action with an optional :format" do
      route_to('/blogposts/new',    :method => :get).should have_route(:controller => 'blogposts', :action => 'new', :id => nil, :format => nil)
      route_to('/blogposts/new.js', :method => :get).should have_route(:controller => 'blogposts', :action => 'new', :id => nil, :format => "js")
    end
    
    it "should not match post on the new action" do
      route_to('/blogposts/new',     :method => :post).should have_nil_route
      route_to('/blogposts/new.xml', :method => :post).should have_nil_route
    end
  
    it "should have a show action with an optional :format" do
      route_to('/blogposts/1',     :method => :get).should have_route(:controller => 'blogposts', :action => 'show', :id => "1", :format => nil)
      route_to('/blogposts/1.css', :method => :get).should have_route(:controller => 'blogposts', :action => 'show', :id => "1", :format => "css")
    end
  
    it "should have an update action with an optional :format" do
      route_to('/blogposts/1',     :method => :put).should have_route(:controller => 'blogposts', :action => 'update', :id => "1", :format => nil)
      route_to('/blogposts/1.csv', :method => :put).should have_route(:controller => 'blogposts', :action => 'update', :id => "1", :format => "csv")
    end
  
    it "should have a destroy action with an optional :format" do
      route_to('/blogposts/1',     :method => :delete).should have_route(:controller => 'blogposts', :action => 'destroy', :id => "1", :format => nil)
      route_to('/blogposts/1.xxl', :method => :delete).should have_route(:controller => 'blogposts', :action => 'destroy', :id => "1", :format => 'xxl')
    end

    it "should have an edit action with an optional :format" do
      route_to('/blogposts/1/edit',     :method => :get).should have_route(:controller => 'blogposts', :action => 'edit', :id => "1", :format => nil)
      route_to('/blogposts/1/edit.rss', :method => :get).should have_route(:controller => 'blogposts', :action => 'edit', :id => "1", :format => "rss")
    end
    
    it "should not match post, put, or delete on the edit action" do
      [:put, :post, :delete].each do |method|
        route_to('/blogposts/edit',    :method => :post).should  have_nil_route
        route_to('/blogposts/edit.hi', :method => :posts).should have_nil_route
      end
    end
  
    it "should should have a delete action with an optional :format" do
      route_to('/blogposts/1/delete',     :method => :get).should have_route(:controller => 'blogposts', :action => 'delete', :id => "1", :format => nil)
      route_to('/blogposts/1/delete.mp3', :method => :get).should have_route(:controller => 'blogposts', :action => 'delete', :id => "1", :format => "mp3")
    end
    
    it "should not match post, put, or delete on the delete action" do
      [:put, :post, :delete].each do |method|
        route_to('/blogposts/delete',     :method => :post).should have_nil_route
        route_to('/blogposts/delete.flv', :method => :post).should have_nil_route
      end
    end
  end
  
  describe "a customized resource route" do
    
    it "should be able to change the controller that the resource points to" do
      Merb::Router.prepare do
        resources :blogposts, :controller => :posts
      end
      
      route_to('/blogposts').should                   have_route(:controller => "posts")
      route_to('/blogposts/1').should                 have_route(:controller => "posts")
      route_to('/blogposts', :method => :post).should have_route(:controller => "posts")
    end
    
    [:controller_prefix, :namespace].each do |option|
      it "should be able to specify the namespace with #{option.inspect}" do
        Merb::Router.prepare do
          resources :blogposts, option => "admin"
        end
        
        route_to('/blogposts').should have_route(:controller => "admin/blogposts")
      end
    end
    
    it "should be able to set the path prefix" do
      Merb::Router.prepare do
        resources :users, :path => "admins"
      end
      
      route_to("/admins").should have_route(:controller => "users", :action => "index")
    end
  end
  
  describe "a resource with extra actions" do
    
    collection = { :one  => :get, :two => :post, :three => :put, :four  => :delete }
    member     = { :five => :get, :six => :post, :seven => :put, :eight => :delete }
    
    before(:each) do
      Merb::Router.prepare do
        resources :users, :collection => collection, :member => member
      end
    end
    
    # Loop through each method declared on the collection and make sure that they
    # are available only when the request is using the specified method
    collection.each_pair do |action, method|
      it "should be able to add extra #{method} methods on the collection with an optional :format" do
        route_to("/users/#{action}",     :method => method).should have_route(:controller => "users", :action => "#{action}", :id => nil, :format => nil)
        route_to("/users/#{action}.xml", :method => method).should have_route(:controller => "users", :action => "#{action}", :id => nil, :format => "xml")
      end
      
      it "should still route /#{action} on get to show" do
        route_to("/users/#{action}").should have_route(:controller => "users", :action => "show", :id => "#{action}")
      end unless method == :get
      
      it "should still route /#{action} on put to update" do
        route_to("/users/#{action}", :method => :put).should have_route(:controller => "users", :action => "update", :id => "#{action}")
      end unless method == :put
      
      it "should still route /#{action} on delete to destroy" do
        route_to("/users/#{action}", :method => :delete).should have_route(:controller => "users", :action => "destroy", :id => "#{action}")
      end unless method == :delete
      
      it "should not match /#{action} on post to anything" do
        route_to("/users/#{action}", :method => :post).should have_nil_route
      end unless method == :post
    end
    
    member.each_pair do |action, method|
      
      it "should be able to add extra #{method} methods on the member with an optional :format" do
        route_to("/users/2/#{action}",     :method => method).should have_route(:controller => "users", :action => "#{action}", :id => "2", :format => nil)
        route_to("/users/2/#{action}.xml", :method => method).should have_route(:controller => "users", :action => "#{action}", :id => "2", :format => "xml")
      end
      
      other_methods = [:get, :post, :put, :delete] - [method]
      other_methods.each do |other|
        
        it "should not route /#{action} on #{other} to anything" do
          route_to("/users/2/#{action}", :method => other).should have_nil_route
        end
        
      end
    end
  end

  describe "a resource route with custom keys" do
  
    before :each do
      Merb::Router.prepare do
        resources :emails, :keys => ["username", "domain"]
      end 
    end
    
    it "should match a get to /emails/bidule/merbivore_com to the  emails controller and the show action with username => 'bidule', domain => 'merbivore_com'" do
      route_to('/emails/bidule/merbivore_com', :method => :get).should have_route(:controller => 'emails', :action => 'show', :username => "bidule", :domain => "merbivore_com")
    end
    
    it "should match a put to /emails/bidule/merbivore_com to the  emails controller and the update action with username => 'bidule', domain => 'merbivore_com'" do
      route_to('/emails/bidule/merbivore_com', :method => :put).should have_route(:controller => 'emails', :action => 'update', :username => "bidule", :domain => "merbivore_com")
    end
    
    it "should match a delete to /emails/bidule/merbivore_com to the  emails controller and the destroy action with username => 'bidule', domain => 'merbivore_com'" do
      route_to('/emails/bidule/merbivore_com', :method => :delete).should have_route(:controller => 'emails', :action => 'destroy', :username => "bidule", :domain => "merbivore_com")
    end
    
    it "should match a get to /emails/bidule/merbivore_com/edit to the  emails controller and the destroy action with username => 'bidule', domain => 'merbivore_com'" do
      route_to('/emails/bidule/merbivore_com/edit', :method => :get).should have_route(:controller => 'emails', :action => 'edit', :username => "bidule", :domain => "merbivore_com")
    end
    
    it "should not match a put to /emails/bidule/merbivore_com/edit" do
      route_to('/emails/bidule/merbivore_com/edit', :method => :put).should have_nil_route
    end
    
    it "should match a get to /emails/bidule/merbivore_com/delete to the emails controller and the delete action with username => 'bidule', domain => 'merbivore_com'" do
      route_to('/emails/bidule/merbivore_com/delete', :method => :get).should have_route(:controller => 'emails', :action => 'delete', :username => "bidule", :domain => "merbivore_com")
    end
 
  end
end