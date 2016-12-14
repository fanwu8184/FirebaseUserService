# FirebaseUserService
This is written in Swift. It is an API for your convenience to connect your user model with the Firebase. Besides the basic functionalities the Firebase provides, currently, I have added two more. One is handleError which will return customized errors message and save your undefined errors' informations on the database. The other one is activateCurrentUser which will reload firebase current user, set up the login log observer, and fetch current user data. The observer is for current user to detect multi-logins simultaneously. If you don't need the observer, you can use the function activateCurrentUserWithoutObserver instead.</br></br>

Your database will look like this:
<img width="678" alt="screen shot 2016-12-14 at 5 01 42 pm" src="https://cloud.githubusercontent.com/assets/21079726/21171425/266fdee8-c220-11e6-99ec-5b73bc5c4291.png"></br></br>


