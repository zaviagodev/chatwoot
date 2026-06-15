import CaptainResponseHistoryAPI from 'dashboard/api/captain/responseHistory';
import { createStore } from '../storeFactory';

export default createStore({
  name: 'CaptainResponseHistory',
  API: CaptainResponseHistoryAPI,
});
