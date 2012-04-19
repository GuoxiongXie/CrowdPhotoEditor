Feature: Select photo from existing album or Upload a new photo
  As a app user
  I can select the photo from my existing album on the app's page or on Facebook
  I can upload a new photo

Background:

  Given I have signed up using name "Bieber",password "password",email "name@email.com"
  Given I have created an album "college"
  Given I have a picture "college_1.png" in the album "college" 
  Given I have successfully logged in using email "name@email.com",password "password"

Scenario: select the existing photo
  When I follow "college"
  Then I should be on the select photo page
  Then I should see "college_1.png"

  When I check "picture[1]"

  Then I press "Continue"
  Then I should be on the dashboard page
  And I should see "1 Picture(s) selected"
  And I should see "college_1.png"
  
  
Scenario: Upload a new photo and add to an existing album  
  When I press "Upload"
  Then I should be on the upload photo to new album page
  When I follow "add to an existing album"
  Then I should be on the select album page
  When I select "college" from "album_id"
  

  When I attach the file "college_2.png" to "selectPhotoButton"
  And I press "Upload"
  
  Then I should be on the select photo page
  And I should see "college"  
  And I should see "college_2.png"
  
Scenario: Upload a new photo to a new album
  When I press "Upload"
  Then I should be on the upload photo to new album page
  When I fill in "albumName" with "Graduation Commencement"

  When I attach the file "college_2.png" to "selectPhotoButton"
  And I press "Upload"
  
  Then I should be on the select photo page
  And I should see "Graduation Commencement"  
  And I should see "college_2.png"
