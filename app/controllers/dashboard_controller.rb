require "net/http"
require "net/https"
require "rubygems"
require "json"

class DashboardController < ApplicationController
  before_filter :authenticate_user!, :except => [:welcome] 
  
  def uploadToAWS
    user_id = current_user.id
    #@user = current.user
    
    if request.post? #if the user clicked the "upload" button on the form
      
      #first find if user already has album with that name
      if Album.find_by_name(params[:album_name]).nil?
      #if Album.find_by_name_and_user_id(params[:albumName], user_id)==nil
      
        #start create new album,new picture, and upload the file.
        if params[:album_name] and not params[:album_id]
          album = Album.create!(:name => params[:album_name], :user_id => user_id)
        else
          album = Album.find_by_id(params[:album_id]) 
        end          
        #actually uploading photo
        new_photo = Picture.uploadToAWS(params[:upload], album)
        redirect_to :action => "selectPhoto", :album_id => album.id

      else #if user already has album with same name
        flash[:error] = "You already have an album named #{params[:album_name]}, enter a new album name or add to the existing one!"
        redirect_to :action => "uploadPhotoToNew"
      end
    end
  end
  
  def welcome
  end
  
  def index  #displaying facebook albums
    session.delete(:tasks)
    session.delete(:results)
    
    queryList = Query.find_all_by_user_id(current_user.id)
    pendingList = []
    finishedList = []
    queryList.each do |query|
      
      if query.result_link == ""
        #ask the api if the task is finished or not
        response = nil
        url = URI(query.task_link)
        http = Net::HTTP.new(url.host, 443)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.start do |http|
          req = Net::HTTP::Get.new(url.path)
          req.basic_auth("FelixXie","Phoenix1218118")
          response = http.request(req)
          #puts response.body
        end
        #debugger
        parsed_json = ActiveSupport::JSON.decode(response.body)
        
        #if answer = "sth" # finished, update Query table, add it to finishedlist
        if parsed_json["answer"] != ""
          finishedList << query
          query.result_link = parsed_json["answer"]
          query.save
        else #task not finished on api
          pendingList << query
        end
      else #if result_link already exists in db
        #dont ask the api, just add it to finished list, and do the counting  
        finishedList << query
      end
    end
    @len = finishedList.length
#-------------------------------------------------------------
    if session[:picture]==nil
      session[:picture]=Hash.new
    end

    if params[:picture] !=nil 
      params[:picture].each do |key|
        session[:picture][key[0]] = 1
      end
    end
    @selected_picture=session[:picture] || {}
    
    if session[:picturefb]==nil
      session[:picturefb]=Hash.new
    end

    if params[:picturefb] !=nil 
      params[:picturefb].each do |key|
        session[:picturefb][key[0]] = 1
      end
    end
    @selected_picturefb=session[:picturefb] || {}
    
    user_id = current_user.id
    # crowd albums part
    @crowdAlbums = User.find_by_id(user_id).albums
    
    # facebook albums part
    @albums = nil
    auth = Authorization.find_by_user_id(user_id)
    if auth
      token = Authorization.find(current_user.id).token
    end
    @user = User.find_by_id(current_user.id)
    @user_name = User.find_by_id(current_user.id).name
    if token
      result = @user.grap_facebook_albums(token)
      @albums = result
    else
    end
    @pictureSelected = Picture.find(@selected_picture.keys) 
    @picturefbSelected = @selected_picturefb.keys
  end
  
  def showPhoto
    fb_album_id = params[:fb_album_id]
    token = Authorization.find(current_user.id).token
    albums = current_user.grap_facebook_albums(token)
    albums.each do |album|
      if album.identifier == fb_album_id
        @fb_pictures = album.photos
        @fb_album_name = album.name
      end
    end
  end
  
  def selectPhoto  #checkboxes page
    #album_id = params[:album_id]
    album = Album.find_by_id(params[:album_id])
    @album_name = album.name
    @pictures = album.pictures
  end
  
  def uploadPhotoToNew #create new album and upload photo to it
    user_id = current_user.id
    @user = User.find(user_id)
    
    if request.post? #if the user clicked the "upload" button on the form
      
      #first find if user already has album with that name
      if Album.find_by_name_and_user_id(params[:albumName], user_id)==nil
      
        #start create new album,new picture, and upload the file.
        newAlbum = Album.create!(:name => params[:albumName], :user_id => user_id) 
      
        #actually uploading photo
        namePathList = Picture.handleUpload(params[:upload], user_id)
        name = namePathList[0]
        path = namePathList[1]
      
        #create new picture tuple
        newPicture = Picture.create!(:name => name,:internal_link => path, :user_id => user_id, :album_id => newAlbum.id)   
        redirect_to :action => "selectPhoto", :album_id => newAlbum.id

      else #if user already has album with same name
        flash[:error] = "You already have an album named #{params[:albumName]}, please enter a new name!"
        redirect_to :action => "uploadPhotoToNew"
      end


    end
  end
  
  def uploadPhotoToExisting     #upload photo to existing album
    user_id = current_user.id
    @user = User.find(user_id)
    
    if request.post? #if the user clicked the "upload" button on the form
      #start create new album,new picture, and upload the file.
      album_id = params[:album_id]
      
      #actually uploading photo
      namePathList = Picture.handleUpload(params[:upload], user_id)
      name = namePathList[0]
      path = namePathList[1]
      
      #create new picture tuple
      newPicture = Picture.create!(:name => name,:internal_link => path, :user_id => user_id, :album_id => album_id)
     
      redirect_to :action => "selectPhoto", :album_id => album_id
      
      #should reder somewhere at the end
    end
  end
  
  def selectAlbum   
    user_id = current_user.id
    user = User.find(user_id)
    albumList = user.albums
    @lol = [] #@lol is [[al.name,al.id],[al.name,al.id]]
    albumList.each do |al|
      @lol << [al.name,al.id]
    end
  end

  def specifyTask
    if session[:picture] == {} and session[:picturefb] == {}
      flash[:error] = "Please Select Photo(s) Before Specifying Task(s)"
      redirect_to :action => :index
    end

    @selected_picture = session[:picture]
    @selected_picturefb = session[:picturefb]
    @pictureSelected = Picture.find(@selected_picture.keys)
    @picturefbSelected = @selected_picturefb.keys
    @specify_task = params[:tasks] || session[:tasks] || {}
    @specify_result = params[:results] || session[:results] || {}
    user_id = current_user.id
    @user_name = User.find(current_user.id).name
  end

  def reviewTask
    @selected_picture = session[:picture]
    @selected_picturefb = session[:picturefb]
    @pictureSelected = Picture.find(@selected_picture.keys)
    @picturefbSelected = @selected_picturefb.keys
    @specify_task = params[:tasks] || session[:tasks]
    session[:tasks] = @specify_task
    @specify_result = params[:results] || session[:results]
    session[:results] = @specify_result
    user_id = current_user.id
    @user_name = User.find(current_user.id).name
  end
  
  def submit
    @selected_pictures = session[:picture] #hashTable: key is pic id, value is 1
    @selected_picturesfb = session[:picturefb]
    @taskTable = session[:tasks] #key is picture id, value is the task string
    @resultTable = session[:results] #key is picture id, value is the # of result the user wants
    redirect_to :controller => :mobilework, :action => :submit_task, :picTable => @selected_pictures, :picfbTable => @selected_picturesfb, :taskTable => @taskTable, :resultTable => @resultTable
  end
  
  def getResult
    user_id = current_user.id
    @user_name = User.find(current_user.id).name
  end

end
