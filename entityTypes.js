import { getEntityTypes, getUISchema, getPrimaryUISchemas, getJSONSchema } from '@/services/api';

export default {
  namespace: 'entityTypes',

  state: {
    list: [],
    uiSchema: {},
    jsonSchema: {},
  },

  effects: {
    *fetch(_, { call, put }) {
      const response = yield call(getEntityTypes);
      if (!response) return;
      yield put({
        type: 'queryList',
        payload: Array.isArray(response.data) ? response.data : [],
      });
    },

    *queryJSONschemaById({payload}, { call, put }) {
      const response = yield call(getJSONSchema, payload);
      if (response) {
        yield put({
          type: 'setJSONschema',
          payload: response.value,
        });
      }
    },

    *queryUIschemaById({payload}, { call, put }) {
      const response = yield call(getUISchema, payload);
      if (response) {
        yield put({
          type: 'setUIschema',
          payload: response.value,
        });
      }
    },

    *queryPrimaryUIschema({payload}, { call, put }) {
      const response = yield call(getPrimaryUISchemas, payload);
      if (response) {
        yield put({
          type: 'setUIschema',
          payload: Array.isArray(response.data) && response.data[0] ? response.data[0] : {},
        });
      }
    },
  },

  reducers: {
    queryList(state, action) {
      return {
        ...state,
        list: action.payload,
      };
    },

    setUIschema(state, action) {
      return {
        ...state,
        uiSchema: action.payload,
      };
    },

    setJSONschema(state, action) {
      return {
        ...state,
        jsonSchema: action.payload,
      };
    }
  },
};
