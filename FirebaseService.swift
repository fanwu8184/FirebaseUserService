//
//  DataService.swift
//  Managee
//
//  Created by Fan Wu on 11/22/16.
//  Copyright © 2016 8184. All rights reserved.
//

import Foundation
import Firebase

let dataService = FirebaseService()

class FirebaseService {
    
    private struct Constants {
        static let undefinedErrorsNode = "undefinedErrors"
        static let undefinedErrorsMsg = "Something is wrong in an unexpected place. This issue was record, our team will work on it ASAP."
        static let imagePostfix = ".jpg"
        static let usersNode = "users"
        static let usersImagesFolderName = "usersImages"
        static let profile = "profile"
        static let loginLog = "loginLog"
        static let lastActivated = "lastActivated"
    }
    
    static let reauthenticationErrorMessage = "For security reason, please enter your current password."
    private let errorMsgDictionary = [
        //need to populate
        FIRAuthErrorCode.errorCodeEmailAlreadyInUse: "The specified email already exists, please use another one.",
        FIRAuthErrorCode.errorCodeRequiresRecentLogin: FirebaseService.reauthenticationErrorMessage
    ]
    
    private var databaseRef: FIRDatabaseReference { return FIRDatabase.database().reference() }
    private var storageRef: FIRStorageReference { return FIRStorage.storage().reference() }
    private var autoID: String { return FIRDatabase.database().reference().childByAutoId().key }
    
    //---------------------------------------------------------------------------------------------------------
    // MARK: - USER
    //---------------------------------------------------------------------------------------------------------
    
    private var currentUser: FIRUser? { return FIRAuth.auth()?.currentUser }
    var currentUserID: String? {return currentUser?.uid }
    var currentUserEmail: String? { return currentUser?.email }
    var currentUserIsEmailVerified: Bool? { return currentUser?.isEmailVerified }
    
    //-----------------------------------------GENERAL---------------------------------------------------------
    //sign up with a completion to deal with a sign up error
    func signUp(userEmail: String, userPassword: String, signUpCompletion: ((String?) -> Void)?) {
        FIRAuth.auth()?.createUser(withEmail: userEmail, password: userPassword) { (firUser, error) in
            signUpCompletion?(self.handleError(error))
        }
    }
    
    //sign in with a completion to deal with a sign in error
    func signIn(userEmail: String, userPassword: String, signInCompletion: ((String?) -> Void)?) {
        FIRAuth.auth()?.signIn(withEmail: userEmail, password: userPassword) { (firUser, error) in
            signInCompletion?(self.handleError(error))
        }
    }

    //logout
    func logout() { try? FIRAuth.auth()?.signOut() }
    
    //send a verification email to current user with a completion to deal with an error
    func sendVerificationEmail(sendCompletion: ((String?) -> Void)?) {
        currentUser?.sendEmailVerification { (error) in sendCompletion?(self.handleError(error)) }
    }
    
    //send a password reset mail to a user with a completion to deal with an error
    func forgotPassword(userEmail email: String, sendCompletion: ((String?) -> Void)?) {
        FIRAuth.auth()?.sendPasswordReset(withEmail: email) { (error) in sendCompletion?(self.handleError(error)) }
    }

    //update current user's email with a completion to deal with an error
    func updateEmail(newEmail: String, updateCompletion: ((String?) -> Void)?) {
        currentUser?.updateEmail(newEmail) { error in updateCompletion?(self.handleError(error)) }
    }
    
    //update current user's password with a completion to deal with an error
    func updatePassword(newPassword: String, updateCompletion: ((String?) -> Void)?) {
        currentUser?.updatePassword(newPassword) { (error) in updateCompletion?(self.handleError(error)) }
    }

    //delete current user's account, and remove all the files and data associated with the users
    func deleteAccount(deleteCompletion: ((String?) -> Void)?) {
        currentUser?.delete { (delUserError) in deleteCompletion?(self.handleError(delUserError)) }
    }
    
    //reauthenticate current user with a completion to deal with an error
    func reauthenticate(inputPassword: String, reauthCompletion: ((String?) -> Void)?) {
        guard let email = currentUserEmail else { return }
        let credential = FIREmailPasswordAuthProvider.credential(withEmail: email, password: inputPassword)
        currentUser?.reauthenticate(with: credential) { (error) in reauthCompletion?(self.handleError(error)) }
    }
    
    //-----------------------------------------SPECIFIC---------------------------------------------------------
    //save a user's data with a completion to deal with a save error
    func saveUserProfileData(userID: String, value: [String: Any], saveCompletion: ((String?) -> Void)?) {
        let p = fetchUserProfilePath(uid: userID)
        saveData(path: p, save: value) { (errMsg) in saveCompletion?(errMsg) }
    }
    
    //save current user's image with a completion to deal with a save error and url of image
    func saveCurrentUserImage(imageData: Data, saveCompletion: ((String?, String?) -> Void)?) {
        guard let id = currentUserID else { return }
        let p = fetchUserImagePath(uid: id)
        saveFile(path: p, fileData: imageData) { (errMsg, url) in saveCompletion?(errMsg, url) }
    }
    
    //fetch a user's data base on the userID with a completion to deal with a snapshot and an error
    func fetchUserData(userID: String, completion: ((NSDictionary?, String?) -> Void)?) {
        let p = fetchUserProfilePath(uid: userID)
        databaseRef.child(p).observeSingleEvent(of: .value, with: { (snapshot) in
            let value = snapshot.value as? NSDictionary
            completion?(value, nil)
        }) { (error) in completion?(nil, self.handleError(error)) }
    }
    
    //delete current user's data a completion to deal with a delete error
    func deleteCurrentUserData(deleteCompletion: ((String?) -> Void)?) {
        guard let id = currentUserID else { return }
        let p = fetchUserDataPath(uid: id)
        deleteData(path: p) { (errMsg) in deleteCompletion?(errMsg) }
    }
    
    //delete current user's image with a completion to deal with a delete error
    func deleteCurrentUserImage(deleteCompletion: ((String?) -> Void)?) {
        guard let id = currentUserID else { return }
        let p = fetchUserImagePath(uid: id)
        deleteFile(path: p) { (errMsg) in deleteCompletion?(errMsg) }
    }
    
    //reload firebase current user, set up the login log observer, and fetch current user data
    func activateCurrentUser(observerAction: ((String?) -> Void)?, activateCompletion: ((NSDictionary?, String?) -> Void)?) {
        guard let uid = currentUserID else { activateCompletion?(nil, nil); return }
        reloadCurrentUser { (reloadErrMsg) in
            if reloadErrMsg == nil {
                self.setUpLoginLogObserver { (setUpErrMsg) in observerAction?(setUpErrMsg) }
                self.fetchUserData(userID: uid) { (value, fetchErrMsg) in activateCompletion?(value, fetchErrMsg) }
            } else { activateCompletion?(nil, reloadErrMsg) }
        }
    }
    
    //reload firebase current user and fetch current user data
    func activateCurrentUserWithoutObserver(activateCompletion: ((NSDictionary?, String?) -> Void)?) {
        guard let uid = currentUserID else { activateCompletion?(nil, nil); return }
        reloadCurrentUser { (reloadErrMsg) in
            if reloadErrMsg == nil {
                self.fetchUserData(userID: uid) { (value, fetchErrMsg) in activateCompletion?(value, fetchErrMsg) }
            } else { activateCompletion?(nil, reloadErrMsg) }
        }
    }
    
    //remove the login log observer for current user
    func inactivateCurrentUser() {
        guard let uid = currentUserID else { return }
        removeLoginLogObserver(userID: uid)
    }
    
    //-----------------------------------------PRIVATE---------------------------------------------------------
    //fetch a user's data path
    private func fetchUserDataPath(uid: String) -> String { return "/\(Constants.usersNode)/\(uid)" }
    
    //fetch a user's profile data path
    private func fetchUserProfilePath(uid id: String) -> String { return "\(fetchUserDataPath(uid: id))/\(Constants.profile)" }
    
    //fetch a user's login log data path
    private func fetchUserLoginLogPath(uid id: String) -> String { return "\(fetchUserDataPath(uid: id))/\(Constants.loginLog)" }
    
    //fetch a user's image path
    private func fetchUserImagePath(uid: String) -> String { return "\(Constants.usersImagesFolderName)/\(uid)\(Constants.imagePostfix)" }
    
    //reload Firebase's current user
    private func reloadCurrentUser(completion: ((String?) -> Void)?) {
        currentUser?.reload { (error) in completion?(self.handleError(error)) }
    }
    
    //set up the login log observer for current user to detect multi-logins simultaneously
    private func setUpLoginLogObserver(completion: ((String?) -> Void)?) {
        guard let id = currentUserID else { return }
        let p = fetchUserLoginLogPath(uid: id)
        //update the login date first
        saveData(path: p, save: [Constants.lastActivated: Date().description]) { (errMsg) in
            if errMsg == nil {
                self.databaseRef.child(p).observe(.childChanged, with: { (firSnapshot) in completion?(nil) }) { (error) in
                    completion?(self.handleError(error))
                }
            } else { completion?(errMsg) }
        }
    }
    
    //remove the login log observer for a user
    private func removeLoginLogObserver(userID: String) {
        let path = fetchUserLoginLogPath(uid: userID)
        databaseRef.child(path).removeAllObservers()
    }
    
    //---------------------------------------------------------------------------------------------------------
    // MARK: - GENERAL PRIVATE
    //---------------------------------------------------------------------------------------------------------
    //return customized error message and save undefined error info. on the database
    private func handleError(_ error: Error?) -> String? {
        if error == nil { return nil } else {
            print("this is error: \(error?.localizedDescription)") //..........
            guard let code = (error as? NSError)?.code,
                let errCode = FIRAuthErrorCode(rawValue: code) else { return Constants.undefinedErrorsMsg }
            guard let message = errorMsgDictionary[errCode] else {
                let undefinedErrorID = autoID
                let undefinedErrorDescription = error!.localizedDescription
                let value = [undefinedErrorID: undefinedErrorDescription]
                saveData(path: Constants.undefinedErrorsNode, save: value, completion: nil)
                return Constants.undefinedErrorsMsg
            }
            return message
        }
    }
    
    //save a value on a path with a completion to deal with a save error
    private func saveData(path: String, save value: Any, completion: ((String?) -> Void)?) {
        databaseRef.updateChildValues([path: value]) { (error, ref) in completion?(self.handleError(error)) }
    }
    
    //save two values on two paths synchronously with a completion to deal with a save error
    private func saveDataSynchronous(pathA: String, valueA: Any, pathB: String, valueB: Any, completion: ((String?) -> Void)?) {
        databaseRef.updateChildValues([pathA: valueA, pathB: valueB]) { (error, ref) in completion?(self.handleError(error)) }
    }
    
    //delete a data on a path with a completion to deal with a delete error
    private func deleteData(path: String, completion: ((String?) -> Void)?) {
        databaseRef.updateChildValues([path: NSNull()]) { (error, ref) in completion?(self.handleError(error)) }
    }
    
    //save a file on a path with a completion to deal with a save error and an url of file
    private func saveFile(path: String, fileData: Data, completion: ((String?, String?) -> Void)?) {
        storageRef.child(path).put(fileData, metadata: nil) { (metadata, error) in
            completion?(self.handleError(error), metadata?.downloadURL()?.absoluteString)
        }
    }
    
    //delete a file on a path with a completion to deal with a delete error
    private func deleteFile(path: String, completion: ((String?) -> Void)?) {
        storageRef.child(path).delete { (error) in completion?(self.handleError(error)) }
    }
}
