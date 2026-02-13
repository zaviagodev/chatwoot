/* global axios */

import Cookies from 'js-cookie';
import endPoints from './endPoints';
import {
  clearCookiesOnLogout,
  deleteIndexedDBOnLogout,
} from '../store/utils/api';

// localStorage key for auth (works in iframes where cookies are blocked)
const AUTH_STORAGE_KEY = 'cw_d_session_info_ls';

export default {
  validityCheck() {
    const urlData = endPoints('validityCheck');
    return axios.get(urlData.url);
  },
  logout() {
    const urlData = endPoints('logout');
    const fetchPromise = new Promise((resolve, reject) => {
      axios
        .delete(urlData.url)
        .then(response => {
          deleteIndexedDBOnLogout();
          clearCookiesOnLogout();
          resolve(response);
        })
        .catch(error => {
          reject(error);
        });
    });
    return fetchPromise;
  },
  hasAuthCookie() {
    // Check cookie first, then localStorage (for iframe support)
    if (Cookies.get('cw_d_session_info')) {
      return true;
    }
    try {
      const lsAuth = localStorage.getItem(AUTH_STORAGE_KEY);
      if (lsAuth) {
        // Check expiry
        const expiry = localStorage.getItem(AUTH_STORAGE_KEY + '_expiry');
        if (expiry && new Date(expiry) > new Date()) {
          return true;
        }
      }
    } catch (e) {
      // localStorage not available
    }
    return false;
  },
  getAuthData() {
    // Try cookie first
    const cookieAuth = Cookies.get('cw_d_session_info');
    if (cookieAuth) {
      return JSON.parse(cookieAuth);
    }

    // Fall back to localStorage (for iframe support)
    try {
      const lsAuth = localStorage.getItem(AUTH_STORAGE_KEY);
      if (lsAuth) {
        const expiry = localStorage.getItem(AUTH_STORAGE_KEY + '_expiry');
        if (expiry && new Date(expiry) > new Date()) {
          return JSON.parse(lsAuth);
        }
      }
    } catch (e) {
      // localStorage not available
    }

    return false;
  },
  profileUpdate({ displayName, avatar, ...profileAttributes }) {
    const formData = new FormData();
    Object.keys(profileAttributes).forEach(key => {
      const hasValue = profileAttributes[key] === undefined;
      if (!hasValue) {
        formData.append(`profile[${key}]`, profileAttributes[key]);
      }
    });
    formData.append('profile[display_name]', displayName || '');
    if (avatar) {
      formData.append('profile[avatar]', avatar);
    }
    return axios.put(endPoints('profileUpdate').url, formData);
  },

  profilePasswordUpdate({ currentPassword, password, passwordConfirmation }) {
    return axios.put(endPoints('profileUpdate').url, {
      profile: {
        current_password: currentPassword,
        password,
        password_confirmation: passwordConfirmation,
      },
    });
  },

  updateUISettings({ uiSettings }) {
    return axios.put(endPoints('profileUpdate').url, {
      profile: { ui_settings: uiSettings },
    });
  },

  updateAvailability(availabilityData) {
    return axios.post(endPoints('availabilityUpdate').url, {
      profile: { ...availabilityData },
    });
  },

  updateAutoOffline(accountId, autoOffline = false) {
    return axios.post(endPoints('autoOffline').url, {
      profile: { account_id: accountId, auto_offline: autoOffline },
    });
  },

  deleteAvatar() {
    return axios.delete(endPoints('deleteAvatar').url);
  },

  resetPassword({ email }) {
    const urlData = endPoints('resetPassword');
    return axios.post(urlData.url, { email });
  },

  setActiveAccount({ accountId }) {
    const urlData = endPoints('setActiveAccount');
    return axios.put(urlData.url, {
      profile: {
        account_id: accountId,
      },
    });
  },
  resendConfirmation() {
    const urlData = endPoints('resendConfirmation');
    return axios.post(urlData.url);
  },
  resetAccessToken() {
    const urlData = endPoints('resetAccessToken');
    return axios.post(urlData.url);
  },
};
