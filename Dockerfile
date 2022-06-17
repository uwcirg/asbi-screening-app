FROM node:16 as build-deps
WORKDIR /opt/app

ARG VUE_APP_WRITE_BACK_MODE=${VUE_APP_WRITE_BACK_MODE}
ARG VUE_APP_QUESTIONNAIRE_AUTHOR=${VUE_APP_QUESTIONNAIRE_AUTHOR}
ARG VUE_APP_FHIR_OBSERVATION_CATEGORY_QUERIES=${VUE_APP_FHIR_OBSERVATION_CATEGORY_QUERIES}
ARG VUE_APP_SCREENING_INSTRUMENT=${VUE_APP_SCREENING_INSTRUMENT}
ARG VUE_APP_FHIR_RESOURCES=${VUE_APP_FHIR_RESOURCES}

# cache hack; very fragile
# only copy files `yarn` needs to run
# avoids accidental cache invalidation by changes in code
COPY package.json yarn.lock ./
RUN yarn

COPY . .
RUN yarn build



FROM nginx as production
COPY --from=build-deps /opt/app/dist /usr/share/nginx/html
