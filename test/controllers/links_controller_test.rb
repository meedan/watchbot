require File.join(File.expand_path(File.dirname(__FILE__)), '..', 'test_helper')

class LinksControllerTest < ActionController::TestCase

  def setup
    Link.delete_all
    ApiKey.delete_all
  end

  test "should create link" do
    authorize
    post :create, url: 'http://test.com'
    assert_response :success
  end

  test "should not create link if URL is not present" do
    authorize
    post :create, url: nil
    assert_response 400
  end

  test "should not create link if URL is not valid" do
    authorize
    post :create, url: 'test'
    assert_response 400
  end

  test "should not destroy link if URL is not present" do
    authorize
    delete :destroy, id: ''
    assert_response 400
  end

  test "should not destroy link if URL is not found" do
    authorize
    delete :destroy, id: 'http://test.org'
    assert_response 404
  end

  test "should destroy link" do
    authorize
    create_link url: 'http://test.net'
    assert_difference 'Link.count', -1 do
      delete :destroy, id: 'http://test.net'
    end
    assert_response :success
  end

  test "should not destroy link if exception is raised" do
    authorize
    Link.any_instance.expects(:destroy!).raises(RuntimeError)
    create_link url: 'http://test.net'
    delete :destroy, id: 'http://test.net'
    assert_response 400
  end

  test "should not have access without credentials" do
    post :create, url: 'http://test.com'
    assert_response 401    
  end

  test "should not have access if token expired" do
    api_key = create_api_key
    api_key.expire_at = Time.now.ago(1.second)
    api_key.save!
    authorize(api_key)
    post :create, url: 'http://test.com'
    assert_response 401    
  end

end
